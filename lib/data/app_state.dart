import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../core/format.dart';
import '../services/notifications.dart';
import 'models.dart';

class TxFilter {
  final DateTime? from;
  final DateTime? to;
  final Set<int> categories;
  final int? type;
  final String text;

  const TxFilter({this.from, this.to, this.categories = const {}, this.type, this.text = ''});
}

class DayGroup {
  final int day;
  final List<Txn> items;
  int spent = 0;
  int income = 0;
  DayGroup(this.day, this.items);
}

/// Estado global. Todas las agregaciones se hacen en SQL (indexado por `day`)
/// para que la app se mantenga rápida aunque haya años de registros.
class AppState extends ChangeNotifier {
  AppState(this.db);
  final Database db;

  bool ready = false;
  List<Category> categories = [];
  final Map<int, Category> catById = {};

  int balance = 0;
  int todaySpent = 0;
  int todayIncome = 0;
  int monthSpent = 0;
  int monthIncome = 0;
  int lastMonthSpentToDate = 0;
  Map<int, int> monthByCat = {};
  List<Txn> today = [];
  int streak = 0;
  int noSpendDays = 0;
  List<Reminder> pending = [];
  List<Reminder> done = [];

  // Ahorro (chanchito)
  int? savingsId;
  int saved = 0;
  int monthSaved = 0;
  final Map<String, String> settings = {};

  Category? get savingsCat => savingsId == null ? null : catById[savingsId];
  int? get goal => int.tryParse(settings['savings_goal'] ?? '');
  String get goalName => settings['savings_goal_name'] ?? '';

  /// Meta efectiva: la definida por el usuario o el siguiente hito de $100.
  int get effectiveGoal {
    final g = goal;
    if (g != null && g > 0) return g;
    const step = 10000;
    return ((saved ~/ step) + 1) * step;
  }

  /// Condición SQL que excluye el módulo de ahorro (no cuenta como gasto).
  String get _ns => 'COALESCE(category_id,-1)<>${savingsId ?? -1}';

  /// Se incrementa cada vez que cambian los movimientos (pantallas de historial
  /// y estadísticas lo escuchan para volver a consultar).
  final ValueNotifier<int> txVersion = ValueNotifier(0);

  Future<void> load() async {
    await _loadSettings();
    await _ensureSavings();
    await _loadCategories();
    await Future.wait([_loadSummary(), _loadReminders()]);
    ready = true;
    notifyListeners();
  }

  // ---------------- Ajustes y ahorro ----------------
  Future<void> _loadSettings() async {
    settings
      ..clear()
      ..addAll({for (final r in await db.query('settings')) r['key'] as String: (r['value'] as String?) ?? ''});
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      settings.remove(key);
      await db.delete('settings', where: 'key=?', whereArgs: [key]);
    } else {
      settings[key] = value;
      await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    notifyListeners();
  }

  Future<void> setGoal(int? cents, String name) async {
    await setSetting('savings_goal', cents == null || cents <= 0 ? null : '$cents');
    await setSetting('savings_goal_name', name.trim().isEmpty ? null : name.trim());
  }

  /// Garantiza que exista el módulo especial "Ahorro".
  Future<void> _ensureSavings() async {
    final r = await db.query('categories', where: 'kind=?', whereArgs: [Category.savingsKind], limit: 1);
    if (r.isEmpty) {
      await db.insert('categories', {
        'name': 'Ahorro',
        'icon': 'savings',
        'color': 0xFFF2C64B,
        'sort': -1,
        'archived': 0,
        'kind': Category.savingsKind,
      });
    } else if ((r.first['archived'] as int? ?? 0) == 1) {
      await db.update('categories', {'archived': 0}, where: 'id=?', whereArgs: [r.first['id']]);
    }
  }

  /// Meter dinero al chanchito: sale del saldo disponible.
  Future<void> deposit(int cents, String note) => saveTxn(Txn(
        type: TxType.expense,
        amount: cents,
        note: note,
        categoryId: savingsId,
        date: DateTime.now(),
      ));

  /// Sacar dinero del chanchito: vuelve al saldo disponible.
  Future<void> withdraw(int cents, String note) => saveTxn(Txn(
        type: TxType.income,
        amount: cents,
        note: note,
        categoryId: savingsId,
        date: DateTime.now(),
      ));

  // ---------------- Categorías ----------------
  Future<void> _loadCategories() async {
    final rows = await db.query('categories', orderBy: 'sort, id');
    catById.clear();
    final all = rows.map(Category.fromMap).toList();
    savingsId = null;
    for (final c in all) {
      catById[c.id!] = c;
      if (c.isSavings) savingsId = c.id;
    }
    categories = all.where((c) => !c.archived).toList();
  }

  Future<int> saveCategory(Category c) async {
    int id;
    if (c.id == null) {
      final maxSort = categories.isEmpty ? 0 : categories.map((e) => e.sort).reduce((a, b) => a > b ? a : b) + 1;
      id = await db.insert('categories', c.copyWith(sort: maxSort).toMap()..remove('id'));
    } else {
      id = c.id!;
      await db.update('categories', c.toMap(), where: 'id=?', whereArgs: [c.id]);
    }
    await _loadCategories();
    notifyListeners();
    return id;
  }

  /// Si el módulo tiene movimientos se archiva (el historial se conserva);
  /// si está vacío se borra definitivamente.
  Future<void> deleteCategory(Category c) async {
    if (c.isSavings) return; // el módulo de ahorro no se elimina
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM txns WHERE category_id=?', [c.id])) ?? 0;
    if (n == 0) {
      await db.delete('categories', where: 'id=?', whereArgs: [c.id]);
    } else {
      await db.update('categories', {'archived': 1}, where: 'id=?', whereArgs: [c.id]);
    }
    await _loadCategories();
    notifyListeners();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final list = [...categories];
    list.insert(newIndex, list.removeAt(oldIndex));
    categories = list;
    notifyListeners();
    final batch = db.batch();
    for (var i = 0; i < list.length; i++) {
      batch.update('categories', {'sort': i}, where: 'id=?', whereArgs: [list[i].id]);
    }
    await batch.commit(noResult: true);
    await _loadCategories();
  }

  // ---------------- Movimientos ----------------
  Future<void> _loadSummary() async {
    final now = DateTime.now();
    final tk = dayKey(now);
    final m0 = now.year * 10000 + now.month * 100;
    final prev = DateTime(now.year, now.month - 1, 1);
    final p0 = prev.year * 10000 + prev.month * 100;

    final sid = savingsId ?? -1;
    final r = (await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type=1 THEN amount ELSE -amount END),0) AS bal,
        COALESCE(SUM(CASE WHEN type=0 AND day=? AND $_ns THEN amount END),0) AS ts,
        COALESCE(SUM(CASE WHEN type=1 AND day=? AND $_ns THEN amount END),0) AS ti,
        COALESCE(SUM(CASE WHEN type=0 AND day>? AND day<=? AND $_ns THEN amount END),0) AS ms,
        COALESCE(SUM(CASE WHEN type=1 AND day>? AND day<=? AND $_ns THEN amount END),0) AS mi,
        COALESCE(SUM(CASE WHEN type=0 AND day>? AND day<=? AND $_ns THEN amount END),0) AS lm,
        COALESCE(SUM(CASE WHEN category_id=? THEN (CASE WHEN type=0 THEN amount ELSE -amount END) END),0) AS sv,
        COALESCE(SUM(CASE WHEN category_id=? AND day>? AND day<=? THEN (CASE WHEN type=0 THEN amount ELSE -amount END) END),0) AS msv
      FROM txns''', [tk, tk, m0, m0 + 31, m0, m0 + 31, p0, p0 + now.day, sid, sid, m0, m0 + 31])).first;
    saved = r['sv'] as int;
    monthSaved = r['msv'] as int;
    balance = r['bal'] as int;
    todaySpent = r['ts'] as int;
    todayIncome = r['ti'] as int;
    monthSpent = r['ms'] as int;
    monthIncome = r['mi'] as int;
    lastMonthSpentToDate = r['lm'] as int;

    final cats = await db.rawQuery(
        'SELECT category_id AS c, SUM(amount) AS s FROM txns WHERE type=0 AND day>? AND day<=? GROUP BY category_id',
        [m0, m0 + 31]);
    monthByCat = {for (final row in cats) if (row['c'] != null) row['c'] as int: row['s'] as int};

    today = (await db.query('txns', where: 'day=?', whereArgs: [tk], orderBy: 'ts DESC, id DESC')).map(Txn.fromMap).toList();

    final days = await db.rawQuery('SELECT DISTINCT day FROM txns WHERE day<=? ORDER BY day DESC LIMIT 400', [tk]);
    var s = 0;
    var cursor = dateOnly(now);
    final set = {for (final d in days) d['day'] as int};
    if (!set.contains(tk)) cursor = cursor.subtract(const Duration(days: 1));
    while (set.contains(dayKey(cursor))) {
      s++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    streak = s;

    final spentDays = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(DISTINCT day) FROM txns WHERE type=0 AND day>? AND day<=? AND $_ns', [m0, tk])) ??
        0;
    noSpendDays = now.day - spentDays;
  }

  Future<void> _afterTxChange() async {
    await _loadSummary();
    txVersion.value++;
    notifyListeners();
  }

  Future<int> saveTxn(Txn t) async {
    int id;
    if (t.id == null) {
      id = await db.insert('txns', t.toMap()..remove('id'));
    } else {
      id = t.id!;
      await db.update('txns', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    }
    await _afterTxChange();
    return id;
  }

  Future<void> deleteTxn(Txn t) async {
    await db.delete('txns', where: 'id=?', whereArgs: [t.id]);
    await _afterTxChange();
  }

  Future<void> restoreTxn(Txn t) async {
    await db.insert('txns', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _afterTxChange();
  }

  /// Ajusta el saldo para que quede exactamente en [target].
  Future<void> adjustBalance(int target) async {
    final diff = target - balance;
    if (diff == 0) return;
    await saveTxn(Txn(
      type: diff > 0 ? TxType.income : TxType.expense,
      amount: diff.abs(),
      note: 'Ajuste de saldo',
      date: DateTime.now(),
    ));
  }

  Future<List<Txn>> queryTxns(TxFilter f, {int limit = 2000}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (f.from != null) {
      where.add('day>=?');
      args.add(dayKey(f.from!));
    }
    if (f.to != null) {
      where.add('day<=?');
      args.add(dayKey(f.to!));
    }
    if (f.type != null) {
      where.add('type=?');
      args.add(f.type);
    }
    if (f.categories.isNotEmpty) {
      where.add('category_id IN (${List.filled(f.categories.length, '?').join(',')})');
      args.addAll(f.categories);
    }
    if (f.text.trim().isNotEmpty) {
      where.add('note LIKE ?');
      args.add('%${f.text.trim()}%');
    }
    final rows = await db.query('txns',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'day DESC, ts DESC, id DESC',
        limit: limit);
    return rows.map(Txn.fromMap).toList();
  }

  static List<DayGroup> groupByDay(List<Txn> list) {
    final out = <DayGroup>[];
    for (final t in list) {
      final k = dayKey(t.date);
      if (out.isEmpty || out.last.day != k) out.add(DayGroup(k, []));
      final g = out.last;
      g.items.add(t);
      if (t.isExpense) {
        g.spent += t.amount;
      } else {
        g.income += t.amount;
      }
    }
    return out;
  }

  /// Saldo al cierre de cada día (para mostrar en el historial).
  Future<int> balanceAtEndOf(int day) async {
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COALESCE(SUM(CASE WHEN type=1 THEN amount ELSE -amount END),0) FROM txns WHERE day<=?', [day])) ??
        0;
  }

  // ---------------- Estadísticas ----------------
  Future<Map<int, int>> dailySpent(DateTime from, DateTime to) async {
    final rows = await db.rawQuery(
        'SELECT day, SUM(amount) AS s FROM txns WHERE type=0 AND day>=? AND day<=? AND $_ns GROUP BY day',
        [dayKey(from), dayKey(to)]);
    return {for (final r in rows) r['day'] as int: r['s'] as int};
  }

  Future<Map<int, int>> categorySpent(DateTime from, DateTime to) async {
    final rows = await db.rawQuery(
        'SELECT COALESCE(category_id,-1) AS c, SUM(amount) AS s FROM txns WHERE type=0 AND day>=? AND day<=? AND $_ns GROUP BY c',
        [dayKey(from), dayKey(to)]);
    return {for (final r in rows) r['c'] as int: r['s'] as int};
  }

  /// Totales por mes (yyyymm -> [gastado, ingresado]).
  Future<Map<int, List<int>>> monthlyTotals(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final rows = await db.rawQuery('''
      SELECT day/100 AS ym,
        SUM(CASE WHEN type=0 THEN amount ELSE 0 END) AS s,
        SUM(CASE WHEN type=1 THEN amount ELSE 0 END) AS i
      FROM txns WHERE day>=? AND $_ns GROUP BY ym''', [dayKey(start)]);
    return {for (final r in rows) r['ym'] as int: [r['s'] as int, r['i'] as int]};
  }

  Future<List<Txn>> topExpenses(DateTime from, DateTime to, {int n = 5}) async {
    final rows = await db.query('txns',
        where: 'type=0 AND day>=? AND day<=? AND $_ns',
        whereArgs: [dayKey(from), dayKey(to)],
        orderBy: 'amount DESC',
        limit: n);
    return rows.map(Txn.fromMap).toList();
  }

  // ---------------- Recordatorios ----------------
  Future<void> _loadReminders() async {
    pending = (await db.query('reminders', where: 'done=0', orderBy: 'due')).map(Reminder.fromMap).toList();
    done = (await db.query('reminders', where: 'done=1', orderBy: 'due DESC', limit: 100)).map(Reminder.fromMap).toList();
  }

  Future<void> saveReminder(Reminder r) async {
    var saved = r;
    if (r.id == null) {
      final id = await db.insert('reminders', r.toMap()..remove('id'));
      saved = r.copyWith(id: id);
    } else {
      await db.update('reminders', r.toMap(), where: 'id=?', whereArgs: [r.id]);
    }
    await Notifier.schedule(saved);
    await _loadReminders();
    notifyListeners();
  }

  /// Marca como hecho. Si se repite, avanza a la siguiente fecha.
  Future<void> completeReminder(Reminder r) async {
    if (r.repeat != Repeat.none) {
      var next = Repeat.next(r.due, r.repeat);
      final now = DateTime.now();
      while (next.isBefore(now)) {
        next = Repeat.next(next, r.repeat);
      }
      await saveReminder(r.copyWith(due: next));
    } else {
      await saveReminder(r.copyWith(done: true));
    }
  }

  Future<void> reopenReminder(Reminder r) => saveReminder(r.copyWith(done: false));

  Future<void> deleteReminder(Reminder r) async {
    await db.delete('reminders', where: 'id=?', whereArgs: [r.id]);
    await Notifier.cancel(r.id!);
    await _loadReminders();
    notifyListeners();
  }

  Future<void> rescheduleAll() async {
    await Notifier.cancelAll();
    for (final r in pending) {
      await Notifier.schedule(r);
    }
  }

  // ---------------- Respaldo ----------------
  Future<Map<String, Object?>> exportData() async => {
        'app': 'El Dato',
        'format': 1,
        'dbVersion': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'categories': await db.query('categories'),
        'txns': await db.query('txns'),
        'reminders': await db.query('reminders'),
        'settings': await db.query('settings'),
      };

  /// Reemplaza todos los datos por los del respaldo (en una transacción:
  /// si algo falla, no se pierde nada).
  Future<void> importData(Map<String, dynamic> data) async {
    if (data['app'] != 'El Dato') throw const FormatException('El archivo no es un respaldo de El Dato');
    List<Map<String, Object?>> rows(String k) =>
        ((data[k] as List?) ?? const []).map((e) => Map<String, Object?>.from(e as Map)).toList();
    final cats = rows('categories');
    final txns = rows('txns');
    final rems = rows('reminders');
    // Validación previa.
    for (final c in cats) {
      Category.fromMap(c);
    }
    for (final t in txns) {
      Txn.fromMap(t);
    }
    for (final r in rems) {
      Reminder.fromMap(r);
    }
    await db.transaction((tx) async {
      await tx.delete('txns');
      await tx.delete('categories');
      await tx.delete('reminders');
      final b = tx.batch();
      for (final c in cats) {
        b.insert('categories', Category.fromMap(c).toMap());
      }
      for (final t in txns) {
        b.insert('txns', Txn.fromMap(t).toMap());
      }
      for (final r in rems) {
        b.insert('reminders', Reminder.fromMap(r).toMap());
      }
      // Respaldos antiguos no traen ajustes: en ese caso se conservan los actuales.
      if (data['settings'] is List) {
        b.delete('settings');
        for (final s in rows('settings')) {
          b.insert('settings', {'key': s['key'], 'value': s['value']});
        }
      }
      await b.commit(noResult: true);
    });
    await _loadSettings();
    await _ensureSavings();
    await _loadCategories();
    await _loadReminders();
    await rescheduleAll();
    await _afterTxChange();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
