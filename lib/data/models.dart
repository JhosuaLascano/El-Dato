import '../core/format.dart';

class Category {
  final int? id;
  final String name;
  final String icon;
  final int color;
  final int sort;
  final bool archived;

  /// '' = módulo normal, 'savings' = módulo especial de Ahorro (chanchito).
  final String kind;

  static const savingsKind = 'savings';

  const Category({this.id, required this.name, required this.icon, required this.color, this.sort = 0, this.archived = false, this.kind = ''});

  bool get isSavings => kind == savingsKind;

  Category copyWith({int? id, String? name, String? icon, int? color, int? sort, bool? archived}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        sort: sort ?? this.sort,
        archived: archived ?? this.archived,
        kind: kind,
      );

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'icon': icon, 'color': color, 'sort': sort, 'archived': archived ? 1 : 0, 'kind': kind};

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: m['icon'] as String,
        color: m['color'] as int,
        sort: (m['sort'] as int?) ?? 0,
        archived: (m['archived'] as int? ?? 0) == 1,
        kind: (m['kind'] as String?) ?? '',
      );
}

class TxType {
  static const expense = 0;
  static const income = 1;
}

class Txn {
  final int? id;
  final int type;
  final int amount; // centavos, siempre positivo
  final String note;
  final int? categoryId;
  final DateTime date;

  const Txn({this.id, required this.type, required this.amount, required this.note, this.categoryId, required this.date});

  bool get isExpense => type == TxType.expense;
  int get signed => isExpense ? -amount : amount;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'note': note,
        'category_id': categoryId,
        'ts': date.millisecondsSinceEpoch,
        'day': dayKey(date),
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int?,
        type: m['type'] as int,
        amount: m['amount'] as int,
        note: (m['note'] as String?) ?? '',
        categoryId: m['category_id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
      );
}

class ReminderKind {
  static const pago = 'pago';
  static const tarea = 'tarea';
  static const compra = 'compra';
  static const otro = 'otro';
  static const all = [pago, tarea, compra, otro];
  static const labels = {pago: 'Pago', tarea: 'Tarea', compra: 'Compra', otro: 'Otro'};
}

class Repeat {
  static const none = 'none';
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';
  static const all = [none, daily, weekly, monthly];
  static const labels = {none: 'Una vez', daily: 'Diario', weekly: 'Semanal', monthly: 'Mensual'};

  static DateTime next(DateTime d, String r) {
    switch (r) {
      case daily:
        return d.add(const Duration(days: 1));
      case weekly:
        return d.add(const Duration(days: 7));
      case monthly:
        final m = DateTime(d.year, d.month + 1, 1);
        final last = DateTime(m.year, m.month + 1, 0).day;
        return DateTime(m.year, m.month, d.day > last ? last : d.day, d.hour, d.minute);
      default:
        return d;
    }
  }
}

class Reminder {
  final int? id;
  final String title;
  final String note;
  final String kind;
  final DateTime due;
  final String repeat;
  final int? amount;
  final bool done;

  const Reminder({
    this.id,
    required this.title,
    this.note = '',
    this.kind = ReminderKind.tarea,
    required this.due,
    this.repeat = Repeat.none,
    this.amount,
    this.done = false,
  });

  Reminder copyWith({int? id, String? title, String? note, String? kind, DateTime? due, String? repeat, int? amount, bool? done}) =>
      Reminder(
        id: id ?? this.id,
        title: title ?? this.title,
        note: note ?? this.note,
        kind: kind ?? this.kind,
        due: due ?? this.due,
        repeat: repeat ?? this.repeat,
        amount: amount ?? this.amount,
        done: done ?? this.done,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'kind': kind,
        'due': due.millisecondsSinceEpoch,
        'repeat': repeat,
        'amount': amount,
        'done': done ? 1 : 0,
      };

  factory Reminder.fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as int?,
        title: m['title'] as String,
        note: (m['note'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? ReminderKind.otro,
        due: DateTime.fromMillisecondsSinceEpoch(m['due'] as int),
        repeat: (m['repeat'] as String?) ?? Repeat.none,
        amount: m['amount'] as int?,
        done: (m['done'] as int? ?? 0) == 1,
      );
}
