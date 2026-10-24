import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catatan_uang/data/app_state.dart';
import 'package:catatan_uang/data/db.dart';
import 'package:catatan_uang/data/models.dart';

Future<AppState> make([Map<String, Object> prefsInit = const {}]) async {
  SharedPreferences.setMockInitialValues(prefsInit);
  FlutterSecureStorage.setMockInitialValues({});
  final db = Db();
  await db.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  final s = AppState(db, await SharedPreferences.getInstance());
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final now = DateTime.now();
  final from = DateTime(now.year, now.month);
  final to = DateTime(now.year, now.month + 1);

  test('PIN: baku 6 digit, verifikasi, dan penghapusan', () async {
    final s = await make();
    expect(s.pinEnabled, false);
    expect(s.pinLength, 6);
    await s.setPin('123456');
    expect(s.pinEnabled, true);
    expect(s.pinLength, 6);
    expect(s.pinIsLegacy, false);
    expect(await s.verifyPin('123456'), true);
    expect(await s.verifyPin('654321'), false);
    await s.clearPin();
    expect(s.pinEnabled, false);
  });

  test('PIN: tidak lagi disimpan di SharedPreferences', () async {
    final s = await make();
    await s.setPin('123456');
    expect(s.prefs.getString('pin_hash'), isNull);
    expect(s.prefs.getString('pin_salt'), isNull);
    expect(s.pinEnabled, true);
    expect(await s.verifyPin('123456'), true);
  });

  test('PIN lama (SHA-256 di prefs) bermigrasi ke format baru saat pertama berhasil', () async {
    final legacy = sha256.convert(utf8.encode('garam:123456')).toString();
    final s = await make({'pin_hash': legacy, 'pin_salt': 'garam', 'pin_len': 6});
    expect(s.pinEnabled, true);
    expect(await s.verifyPin('000000'), false);
    expect(s.prefs.getString('pin_hash'), legacy);
    expect(await s.verifyPin('123456'), true);
    expect(s.prefs.getString('pin_hash'), isNull);
    expect(s.prefs.getString('pin_salt'), isNull);
    expect(s.pinEnabled, true);
    expect(await s.verifyPin('123456'), true);
    expect(await s.verifyPin('111111'), false);
  });

  test('PIN: 5 kali salah memicu kunci sementara dan PIN benar ditolak selama terkunci', () async {
    final s = await make();
    await s.setPin('123456');
    for (var i = 1; i <= 4; i++) {
      final r = await s.attemptPin('000000');
      expect(r.ok, false);
      expect(r.locked, false);
      expect(r.triesLeft, 5 - i);
    }
    final r = await s.attemptPin('000000');
    expect(r.locked, true);
    expect(s.pinLockLeft, inInclusiveRange(1, 30));
    final blocked = await s.attemptPin('123456');
    expect(blocked.ok, false);
    expect(blocked.locked, true);
  });

  test('PIN: hitungan salah dan kunci bertahan setelah aplikasi dimuat ulang', () async {
    final s = await make();
    await s.setPin('123456');
    for (var i = 0; i < 5; i++) {
      await s.attemptPin('000000');
    }
    expect(s.pinLockLeft, greaterThan(0));
    // Simulasi proses baru: objek baru, penyimpanan aman yang sama.
    final s2 = AppState(s.db, s.prefs);
    await s2.loadPin();
    expect(s2.pinEnabled, true);
    expect(s2.pinLockLeft, greaterThan(0));
    expect((await s2.attemptPin('123456')).ok, false);
  });

  test('PIN: berhasil masuk mengatur ulang hitungan salah', () async {
    final s = await make();
    await s.setPin('123456');
    await s.attemptPin('000000');
    await s.attemptPin('000000');
    expect((await s.attemptPin('123456')).ok, true);
    final r = await s.attemptPin('000000');
    expect(r.triesLeft, 4);
  });

  test('PIN lama 4 digit tetap valid dan ditandai untuk diperkuat', () async {
    final s = await make();
    await s.setPin('1234');
    expect(s.pinLength, 4);
    expect(s.pinIsLegacy, true);
    expect(await s.verifyPin('1234'), true);
    await s.setPin('123456');
    expect(s.pinIsLegacy, false);
  });

  test('saldo: pemasukan, pengeluaran, dan pindah dana', () async {
    final s = await make();
    final a = s.wallets[0];
    final b = s.wallets[1];
    final inc = s.cats.firstWhere((c) => !c.isExpense);
    final exp = s.cats.firstWhere((c) => c.isExpense);
    await s.saveTx(Tx(id: 't1', type: TxType.income, amount: 1000000, walletId: a.id, categoryId: inc.id, date: now));
    await s.saveTx(Tx(id: 't2', type: TxType.expense, amount: 250000, walletId: a.id, categoryId: exp.id, date: now));
    await s.saveTx(Tx(id: 't3', type: TxType.transfer, amount: 300000, walletId: a.id, toWalletId: b.id, date: now));
    expect(s.balanceOf(a.id), 450000);
    expect(s.balanceOf(b.id), 300000);
    expect(s.netWorth, 750000);
    expect(s.sumBetween(from, to, TxType.expense), 250000);
  });

  test('hutang terhubung dompet bersifat netral di statistik', () async {
    final s = await make();
    final a = s.wallets[0];
    await s.createDebt(Debt(id: 'd1', person: 'Budi', amount: 200000, owedToMe: true), walletId: a.id);
    expect(s.balanceOf(a.id), -200000);
    expect(s.sumBetween(from, to, TxType.expense), 0);

    final d = s.debts.first;
    await s.addPayment(d, 200000, '', walletId: a.id);
    expect(s.balanceOf(a.id), 0);
    expect(d.settled, true);
    expect(s.sumBetween(from, to, TxType.income), 0);

    await s.deletePayment(d, d.payments.first.id);
    expect(s.balanceOf(a.id), -200000);
    expect(d.settled, false);

    await s.deleteDebt(d.id);
    expect(s.balanceOf(a.id), 0);
  });

  test('patungan: hanya bagian sendiri yang jadi pengeluaran', () async {
    final s = await make();
    final a = s.wallets[0];
    await s.createSplit(total: 100000, others: ['Budi', 'Sari'], walletId: a.id, categoryId: null, note: 'Makan');
    expect(s.balanceOf(a.id), -100000);
    expect(s.sumBetween(from, to, TxType.expense), 33334);
    expect(s.debts.length, 2);
    expect(s.debts.every((d) => d.amount == 33333 && d.owedToMe), true);
  });

  test('transaksi berulang dibuat otomatis untuk jadwal yang terlewat', () async {
    final s = await make();
    final a = s.wallets[0];
    final exp = s.cats.firstWhere((c) => c.isExpense);
    final today = DateTime(now.year, now.month, now.day);
    await s.saveRecurring(Recurring(
      id: 'r1',
      type: TxType.expense,
      amount: 50000,
      walletId: a.id,
      categoryId: exp.id,
      freq: Freq.monthly,
      nextDate: DateTime(now.year, now.month - 2, 5),
      anchorDay: 5,
    ));
    final n = await s.processRecurring();
    expect(n >= 2, true);
    expect(s.recurrings.first.nextDate.isAfter(today), true);
    expect(await s.processRecurring(), 0);
  });

  test('cadangan: ekspor lalu pulihkan mengembalikan data', () async {
    final s = await make();
    final a = s.wallets[0];
    final exp = s.cats.firstWhere((c) => c.isExpense);
    await s.saveTx(Tx(id: 't1', type: TxType.expense, amount: 12345, walletId: a.id, categoryId: exp.id, date: now, note: 'uji'));
    final worth = s.netWorth;
    final raw = await s.exportBackup();
    await s.resetAll();
    expect(s.txs.length, 0);
    await s.importBackup(raw);
    expect(s.txs.length, 1);
    expect(s.netWorth, worth);
  });

  test('reset total juga menghapus chat, favorit, persetujuan AI, dan kunci API', () async {
    final s = await make({'chat': '[{"r":"u","t":"halo"}]', 'templates': '[]', 'ai_consent': true, 'last_backup': 1});
    await s.setAiKey('sk-uji');
    expect(s.aiKeySet, true);
    await s.resetAll();
    expect(s.chatJson, isNull);
    expect(s.templates, isEmpty);
    expect(s.aiConsent, false);
    expect(s.lastBackup, isNull);
    expect(s.aiKeySet, false);
  });

  test('rekonsiliasi saldo membuat penyesuaian netral terhadap selisih', () async {
    final s = await make();
    final a = s.wallets[0];
    await s.adjustBalance(a, 500000);
    expect(s.balanceOf(a.id), 500000);
    await s.adjustBalance(a, 450000);
    expect(s.balanceOf(a.id), 450000);
  });

  test('cache agregat ikut diperbarui saat transaksi berubah', () async {
    final s = await make();
    final a = s.wallets[0];
    final exp = s.cats.firstWhere((c) => c.isExpense);
    expect(s.sumBetween(from, to, TxType.expense), 0);
    await s.saveTx(Tx(id: 't1', type: TxType.expense, amount: 1000, walletId: a.id, categoryId: exp.id, date: now));
    expect(s.sumBetween(from, to, TxType.expense), 1000);
    expect(s.byCategory(from, to, TxType.expense)[exp.id], 1000);
    await s.deleteCat(exp.id);
    expect(s.byCategory(from, to, TxType.expense)[null], 1000);
    await s.deleteTx('t1');
    expect(s.sumBetween(from, to, TxType.expense), 0);
  });

  test('streak menghitung hari berturut-turut', () async {
    final s = await make();
    final a = s.wallets[0];
    Future<void> add(String id, int daysAgo) => s.saveTx(Tx(
          id: id,
          type: TxType.expense,
          amount: 1,
          walletId: a.id,
          date: DateTime(now.year, now.month, now.day - daysAgo, 12),
        ));
    await add('a', 0);
    await add('b', 1);
    await add('c', 2);
    await add('d', 4);
    expect(s.streak, 3);
  });

  test('favorit tersimpan dan terbaca kembali', () async {
    final s = await make();
    await s.saveTemplates([
      {'type': 'expense', 'amount': 25000, 'note': 'Kopi'},
    ]);
    expect(s.templates.first['note'], 'Kopi');
  });
}
