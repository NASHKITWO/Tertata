import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cadangan otomatis terenkripsi yang disimpan di penyimpanan privat aplikasi.
///
/// - Berjalan saat aplikasi dibuka bila sudah lewat jadwal (tanpa layanan latar belakang).
/// - Kata sandi disimpan di penyimpanan aman Android agar cadangan bisa dibuat tanpa ditanya.
/// - Hanya [keep] cadangan terbaru yang disimpan.
/// - Berkas ikut terhapus bila aplikasi dicopot; pengguna membagikannya sendiri ke Drive/penyimpanan lain.
class AutoBackup {
  AutoBackup._();

  static const enabledKey = 'auto_bk_on';
  static const daysKey = 'auto_bk_days';
  static const lastKey = 'auto_bk_last';
  static const _pwKey = 'auto_bk_pw';
  static const keep = 5;
  static const dayChoices = [1, 3, 7];

  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  // ---------- fungsi murni (diuji) ----------
  static bool isDue(DateTime? last, DateTime now, int everyDays) {
    if (last == null) return true;
    if (last.isAfter(now)) return true; // jam diubah mundur: jangan menunda tanpa batas
    return now.difference(last) >= Duration(days: everyDays);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String fileName(DateTime t) =>
      'tertata_auto_${t.year}${_two(t.month)}${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}.json';

  static bool isAutoFile(String name) => RegExp(r'^tertata_auto_\d{8}_\d{6}\.json$').hasMatch(name);

  /// Nama berkas yang harus dihapus agar hanya [keepCount] terbaru yang tersisa.
  static List<String> toDelete(List<String> names, {int keepCount = keep}) {
    final sorted = names.where(isAutoFile).toList()..sort((a, b) => b.compareTo(a));
    return sorted.length <= keepCount ? <String>[] : sorted.sublist(keepCount);
  }

  // ---------- status ----------
  static bool isEnabled(SharedPreferences p) => p.getBool(enabledKey) ?? false;
  static int days(SharedPreferences p) {
    final d = p.getInt(daysKey) ?? 3;
    return dayChoices.contains(d) ? d : 3;
  }

  static DateTime? last(SharedPreferences p) {
    final v = p.getInt(lastKey);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  // ---------- berkas ----------
  static Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/auto_backup');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Daftar cadangan otomatis, terbaru lebih dulu.
  static Future<List<File>> files({Directory? dir}) async {
    final d = dir ?? await directory();
    final out = <File>[];
    await for (final e in d.list()) {
      if (e is File && isAutoFile(e.uri.pathSegments.last)) out.add(e);
    }
    out.sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  /// Menulis cadangan lewat berkas sementara lalu mengganti nama, kemudian memangkas yang lama.
  static Future<File> writeAndPrune(Directory dir, String content, DateTime now) async {
    final target = File('${dir.path}/${fileName(now)}');
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
    final names = [for (final f in await files(dir: dir)) f.uri.pathSegments.last];
    for (final n in toDelete(names)) {
      try {
        await File('${dir.path}/$n').delete();
      } catch (_) {}
    }
    return target;
  }

  static Future<String?> storedPassword() => _secure.read(key: _pwKey);

  // ---------- operasi ----------
  /// Menyalakan fitur dan langsung membuat cadangan pertama. [export] membuat isi cadangan terenkripsi.
  static Future<File> enable(SharedPreferences p, String password, Future<String> Function(String pw) export, {int everyDays = 3}) async {
    await _secure.write(key: _pwKey, value: password);
    await p.setBool(enabledKey, true);
    await p.setInt(daysKey, dayChoices.contains(everyDays) ? everyDays : 3);
    return runNow(p, export);
  }

  /// Mematikan fitur dan menghapus kata sandi tersimpan. Berkas lama dibiarkan kecuali [deleteFiles].
  static Future<void> disable(SharedPreferences p, {bool deleteFiles = false}) async {
    await p.setBool(enabledKey, false);
    await _secure.delete(key: _pwKey);
    if (deleteFiles) await deleteAllFiles();
  }

  static Future<void> deleteAllFiles() async {
    try {
      final d = await directory();
      await for (final e in d.list()) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Menghapus semuanya: dipanggil saat "Hapus semua data" atau "Lupa PIN".
  static Future<void> wipe(SharedPreferences p) async {
    for (final k in const [enabledKey, daysKey, lastKey]) {
      await p.remove(k);
    }
    await _secure.delete(key: _pwKey);
    await deleteAllFiles();
  }

  static Future<File> runNow(SharedPreferences p, Future<String> Function(String pw) export) async {
    final pw = await _secure.read(key: _pwKey);
    if (pw == null || pw.isEmpty) throw StateError('Kata sandi cadangan otomatis tidak ditemukan. Nyalakan ulang fitur ini.');
    final raw = await export(pw);
    final f = await writeAndPrune(await directory(), raw, DateTime.now());
    await p.setInt(lastKey, DateTime.now().millisecondsSinceEpoch);
    return f;
  }

  /// Dipanggil saat aplikasi dibuka. Mengembalikan berkas baru, atau null bila belum waktunya/mati.
  static Future<File?> runIfDue(SharedPreferences p, Future<String> Function(String pw) export) async {
    if (!isEnabled(p)) return null;
    if (!isDue(last(p), DateTime.now(), days(p))) return null;
    return runNow(p, export);
  }
}
