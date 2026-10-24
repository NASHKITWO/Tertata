import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Satu notifikasi transaksi yang ditangkap layanan native Android dan menunggu dicatat.
class InboxItem {
  const InboxItem({required this.id, required this.pkg, required this.text, required this.time});
  final String id;
  final String pkg;
  final String text;
  final DateTime time;

  /// Nama aplikasi sumber (bila dikenal), dipakai sebagai petunjuk dompet.
  String? get appLabel => kAppLabels[pkg];

  /// Teks yang diberikan ke pembaca notifikasi: nama aplikasi di depan membantu menebak dompet.
  String get parseText => appLabel == null ? text : '$appLabel: $text';
}

const kAppLabels = <String, String>{
  'com.gojek.app': 'GoPay',
  'com.gojek.gopay': 'GoPay',
  'ovo.id': 'OVO',
  'id.dana': 'DANA',
  'com.shopee.id': 'ShopeePay',
  'com.telkom.mwallet': 'LinkAja',
  'com.bca': 'BCA',
  'com.bca.mybca.omni.android': 'BCA',
  'id.bmri.livin': 'Mandiri',
  'src.com.bni': 'BNI',
  'id.co.bri.brimo': 'BRI',
  'com.jago.digitalBanking': 'Jago',
  'com.bsm.activity2': 'BSI',
  'com.btpn.dc': 'Jenius',
  'com.bcadigital.blu': 'blu',
  'id.co.cimbniaga.mobile.android': 'CIMB',
  'id.flip': 'Flip',
  'net.myinfosys.PermataMobileX': 'Permata',
};

/// Jembatan ke kode native Android (kotak masuk notifikasi, widget, aksi cepat).
/// Di platform lain, atau bila kode native belum terpasang, semua pemanggilan aman dan mengembalikan nilai kosong.
class NativeBridge {
  static const _ch = MethodChannel('tertata/native');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> notifAccessEnabled() async => (await _call<bool>('notifAccessEnabled')) ?? false;

  static Future<void> openNotifSettings() async {
    await _call<bool>('openNotifSettings');
  }

  static Future<bool> smsEnabled() async => (await _call<bool>('getCaptureSms')) ?? false;

  static Future<void> setSms(bool on) async {
    await _call<bool>('setCaptureSms', {'on': on});
  }

  static List<InboxItem> decodeItems(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <InboxItem>[];
      for (final m in list) {
        if (m is! Map) continue;
        final text = '${m['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        out.add(InboxItem(
          id: '${m['id'] ?? ''}',
          pkg: '${m['pkg'] ?? ''}',
          text: text,
          time: DateTime.fromMillisecondsSinceEpoch((m['time'] is num) ? (m['time'] as num).toInt() : 0),
        ));
      }
      out.sort((a, b) => b.time.compareTo(a.time));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<InboxItem>> pending() async => decodeItems(await _call<String>('getPending'));

  static Future<void> clearPending() async {
    await _call<bool>('clearPending');
  }

  /// Menyalakan/mematikan blokir tangkapan layar (FLAG_SECURE) di Android.
  static Future<void> setSecure(bool on) async {
    await _call<bool>('setSecure', {'on': on});
  }

  static Future<void> updateWidget(String json) async {
    await _call<bool>('updateWidget', {'json': json});
  }

  /// Aksi yang diminta saat aplikasi dibuka dari widget (mis. "quick_add"); dibaca sekali.
  static Future<String?> launchAction() => _call<String>('getLaunchAction');
}
