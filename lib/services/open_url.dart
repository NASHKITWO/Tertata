import 'package:url_launcher/url_launcher.dart';

/// Membuka tautan https di aplikasi luar (browser / pengunduh). Mengembalikan false bila gagal.
Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
