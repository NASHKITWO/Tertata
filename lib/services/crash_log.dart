import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_info.dart';

/// Satu catatan error.
class CrashEntry {
  const CrashEntry({required this.time, required this.message, required this.stack});
  final DateTime time;
  final String message;
  final String stack;

  Map<String, Object?> toJson() => {'t': time.toIso8601String(), 'm': message, 's': stack};

  static CrashEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = DateTime.tryParse('${j['t']}');
    if (t == null) return null;
    return CrashEntry(time: t, message: '${j['m'] ?? ''}', stack: '${j['s'] ?? ''}');
  }
}

/// Catatan error LOKAL. Tidak ada yang dikirim otomatis: pengguna sendiri yang memutuskan
/// membagikan laporannya (Pengaturan > Laporan masalah).
class CrashLog {
  CrashLog._();

  static const _key = 'crash_log';
  static const maxEntries = 20;
  static const _maxMessage = 300;
  static const _maxStack = 1200;

  static SharedPreferences? _prefs;
  static List<CrashEntry> _entries = [];

  static List<CrashEntry> get entries => List.unmodifiable(_entries);

  /// Menghapus deret angka panjang (nomor rekening, nominal besar, dsb.) dan memotong teks.
  static String scrub(String s, {int max = _maxMessage}) {
    final t = s.replaceAll(RegExp(r'\d{6,}'), '•••');
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  /// Memasang penangkap error global dan memuat catatan lama.
  static void install(SharedPreferences prefs) {
    _prefs = prefs;
    _entries = _load(prefs.getString(_key));

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(record(details.exception, details.stack));
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error, stack));
      return true;
    };
  }

  static List<CrashEntry> _load(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final j = jsonDecode(raw);
      if (j is! List) return [];
      final out = <CrashEntry>[];
      for (final e in j) {
        final c = CrashEntry.fromJson(e);
        if (c != null) out.add(c);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> record(Object error, StackTrace? stack) async {
    try {
      final entry = CrashEntry(
        time: DateTime.now(),
        message: scrub('${error.runtimeType}: $error'),
        stack: scrub(stack?.toString() ?? '', max: _maxStack),
      );
      _entries = [entry, ..._entries].take(maxEntries).toList();
      await _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
    } catch (_) {
      // Pencatat error tidak boleh menimbulkan error baru.
    }
  }

  static Future<void> clear() async {
    _entries = [];
    await _prefs?.remove(_key);
  }

  /// Teks laporan yang bisa dibagikan pengguna. Tidak memuat data keuangan.
  static String report(List<CrashEntry> entries, {String platform = ''}) {
    final b = StringBuffer()
      ..writeln('Laporan masalah Tertata')
      ..writeln('Versi: $kAppVersion${platform.isEmpty ? '' : ' · $platform'}')
      ..writeln('Jumlah catatan: ${entries.length}')
      ..writeln();
    for (final e in entries) {
      b
        ..writeln('[${e.time.toIso8601String()}]')
        ..writeln(e.message)
        ..writeln(e.stack)
        ..writeln();
    }
    return b.toString().trimRight();
  }

  static String get platformName => defaultTargetPlatform.name;
}
