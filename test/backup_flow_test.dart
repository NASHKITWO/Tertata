import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catatan_uang/data/app_state.dart';
import 'package:catatan_uang/data/db.dart';
import 'package:catatan_uang/data/models.dart';
import 'package:catatan_uang/services/auto_backup.dart';
import 'package:catatan_uang/services/backup_crypto.dart';

Future<AppState> make([Map<String, Object> prefsInit = const {}]) async {
  SharedPreferences.setMockInitialValues(prefsInit);
  FlutterSecureStorage.setMockInitialValues({});
  final db = Db();
  await db.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  final s = AppState(db, await SharedPreferences.getInstance());
  await s.load();
  return s;
}

Future<void> addExpense(AppState s, String id, double amount) async {
  final w = s.wallets.first;
  final c = s.cats.firstWhere((c) => c.isExpense);
  await s.saveTx(Tx(id: id, type: TxType.expense, amount: amount, walletId: w.id, categoryId: c.id, date: DateTime.now(), note: 'uji'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  // PBKDF2 300.000 putaran di Dart murni bisa memakan beberapa detik.
  const slow = Timeout(Duration(minutes: 3));

  test('alur utuh: cadangan terenkripsi ke berkas otomatis, lalu pulihkan', () async {
    final s = await make();
    await addExpense(s, 't1', 12345);
    await addExpense(s, 't2', 500);
    final worth = s.netWorth;

    final raw = await s.exportBackup(password: 'kuda-biru-91');
    expect(isEncryptedBackup(raw), isTrue);

    final dir = await Directory.systemTemp.createTemp('tertata_flow_');
    addTearDown(() => dir.delete(recursive: true));
    final file = await AutoBackup.writeAndPrune(dir, raw, DateTime(2026, 10, 24, 8));
    final saved = await file.readAsString();

    final plain = await decryptBackup(saved, 'kuda-biru-91');
    await s.resetAll();
    expect(s.txs, isEmpty);
    await s.importBackup(plain);
    expect(s.txs.length, 2);
    expect(s.netWorth, worth);
  }, timeout: slow);

  test('kata sandi salah tidak membuka cadangan', () async {
    final s = await make();
    final raw = await s.exportBackup(password: 'kuda-biru-91');
    expect(decryptBackup(raw, 'salah-total-1'), throwsA(isA<BackupException>()));
  }, timeout: slow);

  test('gabungkan tidak menggandakan data yang sudah ada', () async {
    final s = await make();
    await addExpense(s, 't1', 1000);
    final raw = await s.exportBackup();
    await s.importBackup(raw, merge: true);
    await s.importBackup(raw, merge: true);
    expect(s.txs.length, 1);
  });

  test('cadangan bukan Tertata ditolak tanpa menyentuh data', () async {
    final s = await make();
    await addExpense(s, 't1', 1000);
    await expectLater(s.importBackup('{"app":"lain","version":3,"data":{}}'), throwsA(isA<FormatException>()));
    await expectLater(s.importBackup('bukan json'), throwsA(isA<FormatException>()));
    expect(s.txs.length, 1);
  });

  test('hapus semua data juga mematikan jadwal cadangan otomatis', () async {
    final s = await make({'auto_bk_on': true, 'auto_bk_days': 3, 'auto_bk_last': 1});
    expect(AutoBackup.isEnabled(s.prefs), isTrue);
    await s.resetAll();
    expect(AutoBackup.isEnabled(s.prefs), isFalse);
    expect(AutoBackup.last(s.prefs), isNull);
  });

  test('hapus transaksi mengembalikan saldo', () async {
    final s = await make();
    await addExpense(s, 't1', 40000);
    final after = s.netWorth;
    expect(after, -40000);
    await s.deleteTx('t1');
    expect(s.netWorth, 0);
  });
}
