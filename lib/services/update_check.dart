import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_info.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.pageUrl, this.apkUrl, this.notes = ''});
  final String version;
  final String pageUrl;
  final String? apkUrl;
  final String notes;
}

/// Memeriksa rilis terbaru di GitHub. Hanya satu permintaan GET ke api.github.com;
/// tidak ada data pribadi yang dikirim (GitHub tetap melihat alamat IP).
class UpdateCheck {
  UpdateCheck._();

  static const autoKey = 'update_auto';
  static const _lastKey = 'update_last_check';
  static const _interval = Duration(hours: 24);

  /// Berisi info bila ada versi yang lebih baru dari yang terpasang.
  static final ValueNotifier<UpdateInfo?> available = ValueNotifier(null);

  /// Memecah "v5.7.3" / "5.7.3+8" menjadi [5, 7, 3]. Null bila tidak berbentuk versi.
  static List<int>? parseVersion(String v) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
    if (m == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  /// Positif bila a lebih baru dari b, 0 bila sama atau salah satunya tidak valid.
  static int compareVersions(String a, String b) {
    final x = parseVersion(a), y = parseVersion(b);
    if (x == null || y == null) return 0;
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return x[i].compareTo(y[i]);
    }
    return 0;
  }

  static bool _isGithubUrl(String? u) {
    final uri = u == null ? null : Uri.tryParse(u);
    return uri != null && uri.scheme == 'https' && uri.host == 'github.com';
  }

  /// Membaca jawaban API rilis. Null bila tidak lebih baru atau datanya tidak valid.
  static UpdateInfo? parse(Object? json, {String current = kAppVersion}) {
    if (json is! Map) return null;
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'];
    final page = json['html_url'];
    if (tag is! String || page is! String || !_isGithubUrl(page)) return null;
    if (compareVersions(tag, current) <= 0) return null;

    String? apk;
    final assets = json['assets'];
    if (assets is List) {
      String? first;
      for (final a in assets) {
        if (a is! Map) continue;
        final name = a['name'], url = a['browser_download_url'];
        if (name is! String || url is! String || !name.endsWith('.apk') || !_isGithubUrl(url)) continue;
        first ??= url;
        if (name == 'Tertata.apk') apk = url;
      }
      apk ??= first;
    }
    final body = json['body'];
    final notes = body is String ? (body.length > 600 ? '${body.substring(0, 600)}…' : body) : '';
    return UpdateInfo(version: tag.replaceFirst(RegExp(r'^v'), ''), pageUrl: page, apkUrl: apk, notes: notes);
  }

  /// Mengambil rilis terbaru. Melempar bila jaringan gagal.
  static Future<UpdateInfo?> fetch({http.Client? client, String current = kAppVersion}) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(
            Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'},
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 404) return null; // belum ada rilis terbit
      if (r.statusCode != 200) throw Exception('GitHub membalas ${r.statusCode}');
      return parse(jsonDecode(utf8.decode(r.bodyBytes)), current: current);
    } finally {
      if (client == null) c.close();
    }
  }

  /// Dipanggil saat aplikasi dibuka. Paling sering sekali per 24 jam, dan bisa dimatikan pengguna.
  static Future<void> autoCheck(SharedPreferences prefs) async {
    try {
      if (!(prefs.getBool(autoKey) ?? true)) return;
      final last = prefs.getInt(_lastKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _interval.inMilliseconds) return;
      available.value = await fetch();
      await prefs.setInt(_lastKey, now);
    } catch (_) {
      // Diam-diam: tanpa internet bukan masalah.
    }
  }

  /// Pemeriksaan manual dari Pengaturan. Melempar bila gagal supaya bisa ditampilkan.
  static Future<UpdateInfo?> checkNow(SharedPreferences prefs) async {
    final info = await fetch();
    available.value = info;
    await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
    return info;
  }
}
