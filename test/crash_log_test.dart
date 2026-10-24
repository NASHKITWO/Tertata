import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catatan_uang/services/crash_log.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    CrashLog.install(prefs);
    await CrashLog.clear();
  });

  test('angka panjang disamarkan dan teks dipotong', () {
    expect(CrashLog.scrub('rekening 1234567890 gagal'), 'rekening ••• gagal');
    expect(CrashLog.scrub('Rp 5000 ok'), 'Rp 5000 ok');
    expect(CrashLog.scrub('a' * 500).length, 301);
  });

  test('mencatat error dan hanya menyimpan 20 terakhir', () async {
    for (var i = 0; i < 25; i++) {
      await CrashLog.record(StateError('galat $i'), StackTrace.current);
    }
    expect(CrashLog.entries.length, CrashLog.maxEntries);
    expect(CrashLog.entries.first.message, contains('galat 24'));
  });

  test('catatan bertahan setelah dimuat ulang', () async {
    await CrashLog.record(StateError('bertahan'), null);
    final prefs = await SharedPreferences.getInstance();
    CrashLog.install(prefs);
    expect(CrashLog.entries.single.message, contains('bertahan'));
  });

  test('laporan memuat versi dan tidak memuat nomor panjang', () async {
    await CrashLog.record(StateError('no 9988776655'), null);
    final text = CrashLog.report(CrashLog.entries, platform: 'android');
    expect(text, contains('Laporan masalah Tertata'));
    expect(text, contains('android'));
    expect(text, isNot(contains('9988776655')));
  });
}
