import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catatan_uang/common.dart';
import 'package:catatan_uang/data/db.dart';
import 'package:catatan_uang/screens/auto_backup_page.dart';
import 'package:catatan_uang/screens/calc_dialog.dart';
import 'package:catatan_uang/screens/crash_report.dart';
import 'package:catatan_uang/screens/guide.dart';
import 'package:catatan_uang/services/crash_log.dart';

Future<AppState> makeState() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final db = Db();
  await db.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  final s = AppState(db, await SharedPreferences.getInstance());
  await s.load();
  return s;
}

Widget host(AppState s, Widget page) => AppScope(
      state: s,
      child: MaterialApp(theme: buildTheme(Colors.teal, Brightness.light), home: page),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('Laporan masalah: tampilan kosong', (tester) async {
    final s = (await tester.runAsync(makeState))!;
    await tester.runAsync(CrashLog.clear);
    await tester.pumpWidget(host(s, const CrashReportPage()));
    await tester.pump();

    expect(find.text('Laporan masalah'), findsOneWidget);
    expect(find.text('Belum ada masalah tercatat.'), findsOneWidget);
    expect(find.text('Bagikan laporan'), findsNothing);
  });

  testWidgets('Laporan masalah: menampilkan catatan dengan angka panjang disamarkan', (tester) async {
    final s = (await tester.runAsync(makeState))!;
    await tester.runAsync(CrashLog.clear);
    await tester.runAsync(() => CrashLog.record(StateError('rekening 1234567890'), null));
    await tester.pumpWidget(host(s, const CrashReportPage()));
    await tester.pump();

    expect(find.text('Bagikan laporan'), findsOneWidget);
    expect(find.textContaining('StateError'), findsOneWidget);
    expect(find.textContaining('1234567890'), findsNothing);
    expect(find.textContaining('•••'), findsOneWidget);
    expect(find.text('Belum ada masalah tercatat.'), findsNothing);
  });

  testWidgets('Cadangan otomatis: awalnya mati dan tanpa daftar cadangan', (tester) async {
    final s = (await tester.runAsync(makeState))!;
    await tester.pumpWidget(host(s, const AutoBackupPage()));
    await tester.pump();

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
    expect(find.text('Cadangkan sekarang'), findsNothing);
    expect(find.text('Cadangan di HP ini'), findsNothing);
  });

  testWidgets('Panduan: topik tampil dan bisa dibuka', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Colors.teal, Brightness.light), home: const GuidePage()));
    await tester.pump();

    expect(find.text('Panduan'), findsOneWidget);
    expect(find.text('Mencatat transaksi'), findsOneWidget);
    expect(find.textContaining('Ketuk tombol Catat'), findsNothing);

    await tester.tap(find.text('Mencatat transaksi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ketuk tombol Catat'), findsOneWidget);
  });

  testWidgets('Kalkulator: menghitung dan mengembalikan hasil', (tester) async {
    double? hasil;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Colors.teal, Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => hasil = await showCalcDialog(context),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Tombol Pakai nonaktif sebelum ada hitungan yang valid.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pakai')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '25.000+7.500*2');
    await tester.pump();
    expect(find.textContaining('40.000'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pakai'));
    await tester.pumpAndSettle();
    expect(hasil, 40000);
  });
}
