import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

const _schemaVersion = 4;

const _ddl = <String>[
  'CREATE TABLE wallets(id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, initial REAL NOT NULL, color INTEGER NOT NULL, icon INTEGER NOT NULL, archived INTEGER NOT NULL, sort INTEGER NOT NULL)',
  'CREATE TABLE categories(id TEXT PRIMARY KEY, name TEXT NOT NULL, is_expense INTEGER NOT NULL, color INTEGER NOT NULL, icon INTEGER NOT NULL)',
  'CREATE TABLE transactions(id TEXT PRIMARY KEY, type TEXT NOT NULL, amount REAL NOT NULL, wallet_id TEXT NOT NULL, to_wallet_id TEXT, category_id TEXT, date INTEGER NOT NULL, note TEXT NOT NULL, recurring_id TEXT, external_id TEXT, neutral INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL)',
  'CREATE INDEX idx_tx_date ON transactions(date)',
  'CREATE INDEX idx_tx_wallet ON transactions(wallet_id)',
  'CREATE INDEX idx_tx_ext ON transactions(external_id)',
  'CREATE TABLE budgets(id TEXT PRIMARY KEY, category_id TEXT NOT NULL, amount REAL NOT NULL, rollover_from INTEGER)',
  'CREATE TABLE goals(id TEXT PRIMARY KEY, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL, deadline INTEGER, color INTEGER NOT NULL, icon INTEGER NOT NULL)',
  'CREATE TABLE recurring(id TEXT PRIMARY KEY, type TEXT NOT NULL, amount REAL NOT NULL, wallet_id TEXT NOT NULL, to_wallet_id TEXT, category_id TEXT, note TEXT NOT NULL, freq TEXT NOT NULL, next_date INTEGER NOT NULL, end_date INTEGER, anchor_day INTEGER NOT NULL, active INTEGER NOT NULL)',
  'CREATE TABLE debts(id TEXT PRIMARY KEY, person TEXT NOT NULL, amount REAL NOT NULL, owed_to_me INTEGER NOT NULL, due INTEGER, note TEXT NOT NULL, created INTEGER NOT NULL, settled INTEGER NOT NULL)',
  'CREATE TABLE debt_payments(id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, amount REAL NOT NULL, date INTEGER NOT NULL, note TEXT NOT NULL)',
];

class Db {
  static const tables = <String>[
    'wallets',
    'categories',
    'transactions',
    'budgets',
    'goals',
    'recurring',
    'debts',
    'debt_payments',
  ];

  late Database _db;
  Database get raw => _db;

  Future<void> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'catatan_uang.db');
    _db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        singleInstance: path == null,
        onCreate: (db, version) async {
          for (final s in _ddl) {
            await db.execute(s);
          }
        },
        // Dijalankan sqflite di dalam satu transaksi: jika gagal, perubahan dibatalkan.
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE transactions ADD COLUMN external_id TEXT');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_ext ON transactions(external_id)');
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE budgets ADD COLUMN rollover_from INTEGER');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE transactions ADD COLUMN neutral INTEGER NOT NULL DEFAULT 0');
          }
          // versi berikutnya: tambahkan blok `if (oldVersion < 5) { ... }` di sini.
        },
      ),
    );
  }

  Future<List<DbMap>> all(String table) => _db.query(table);

  Future<void> put(String table, DbMap m) => _db.insert(table, m, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> putAll(String table, List<DbMap> rows) async {
    if (rows.isEmpty) return;
    final b = _db.batch();
    for (final m in rows) {
      b.insert(table, m, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<void> remove(String table, String id) => _db.delete(table, where: 'id = ?', whereArgs: [id]);

  Future<Map<String, List<DbMap>>> dump() async {
    final out = <String, List<DbMap>>{};
    for (final t in tables) {
      out[t] = (await _db.query(t)).map((e) => Map<String, Object?>.from(e)).toList();
    }
    return out;
  }

  /// Hapus semua data lalu isi ulang dalam satu transaksi (atomik).
  Future<void> restore(Map<String, List<DbMap>> data) async {
    await _db.transaction((tx) async {
      for (final t in tables) {
        await tx.delete(t);
      }
      for (final t in tables) {
        for (final m in data[t] ?? <DbMap>[]) {
          await tx.insert(t, m, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  /// Menambahkan baris yang belum ada (berdasarkan id); data yang sudah ada tidak diubah.
  Future<void> merge(Map<String, List<DbMap>> data) async {
    await _db.transaction((tx) async {
      for (final t in tables) {
        for (final m in data[t] ?? <DbMap>[]) {
          await tx.insert(t, m, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  Future<void> clearAll() => restore({});
}
