import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catatan_uang/data/db.dart';

void main() {
  sqfliteFfiInit();

  test('migrasi dari skema v1 ke versi terbaru menjaga data lama', () async {
    final dir = Directory.systemTemp.createTempSync('tertata_mig');
    final path = p.join(dir.path, 'lama.db');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Bangun database versi 1 (sebelum external_id, rollover_from, dan neutral ada).
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute('CREATE TABLE transactions(id TEXT PRIMARY KEY, type TEXT NOT NULL, amount REAL NOT NULL, wallet_id TEXT NOT NULL, to_wallet_id TEXT, category_id TEXT, date INTEGER NOT NULL, note TEXT NOT NULL, recurring_id TEXT, created INTEGER NOT NULL)');
          await db.execute('CREATE TABLE budgets(id TEXT PRIMARY KEY, category_id TEXT NOT NULL, amount REAL NOT NULL)');
          await db.insert('transactions', {'id': 't1', 'type': 'expense', 'amount': 25000, 'wallet_id': 'w1', 'date': 1, 'note': 'lama', 'created': 1});
          await db.insert('budgets', {'id': 'b1', 'category_id': 'c1', 'amount': 100000});
        },
      ),
    );
    await old.close();

    // Buka lewat Db (menjalankan onUpgrade).
    final d = Db();
    await d.open(path: path, factory: databaseFactoryFfi);
    addTearDown(() => d.raw.close());

    final tx = (await d.raw.query('transactions')).single;
    expect(tx['id'], 't1');
    expect(tx['amount'], 25000);
    expect(tx['neutral'], 0);
    expect(tx.containsKey('external_id'), true);
    final b = (await d.raw.query('budgets')).single;
    expect(b['amount'], 100000);
    expect(b.containsKey('rollover_from'), true);
  });
}
