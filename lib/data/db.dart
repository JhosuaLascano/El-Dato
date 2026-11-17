import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local. Vive en el almacenamiento interno de la app,
/// así que sobrevive a cada actualización (mismo applicationId + misma firma).
/// Si en el futuro cambia el esquema, se sube [version] y se agrega la
/// migración en [_onUpgrade]; nunca se borran los datos.
class AppDb {
  static const version = 2;

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'el_dato.db'),
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        kind TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS txns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        category_id INTEGER,
        ts INTEGER NOT NULL,
        day INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txns_day ON txns(day)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txns_cat ON txns(category_id, day)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL,
        due INTEGER NOT NULL,
        repeat TEXT NOT NULL DEFAULT 'none',
        amount INTEGER,
        done INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rem_due ON reminders(done, due)');
  }

  static Future<void> _onCreate(Database db, int v) async {
    await createTables(db);
    final defaults = [
      ['Comida', 'food', 0xFFFF9F43],
      ['Transporte', 'transport', 0xFF5B9DFF],
      ['Ocio', 'fun', 0xFFA78BFA],
      ['Educación', 'edu', 0xFF4CC38A],
    ];
    for (var i = 0; i < defaults.length; i++) {
      await db.insert('categories', {
        'name': defaults[i][0],
        'icon': defaults[i][1],
        'color': defaults[i][2],
        'sort': i,
        'archived': 0,
      });
    }
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // v2: módulo de Ahorro (columna kind) y tabla de ajustes (meta de ahorro).
    if (oldV < 2) {
      await db.execute("ALTER TABLE categories ADD COLUMN kind TEXT NOT NULL DEFAULT ''");
      await db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)');
    }
    // Próximas migraciones: if (oldV < 3) { ... }
  }
}
