import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as c;

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Putaran PBKDF2 untuk cadangan baru. Jumlahnya ditulis di header file (`kdf`), jadi menaikkannya
/// tidak merusak cadangan lama (v5.7.1 dan sebelumnya memakai 100.000).
const kBackupIterations = 300000;
const _legacyIterations = 100000;
const _minIterations = 1000;
const _maxIterations = 2000000; // batas atas agar file cadangan berbahaya tidak membuat aplikasi hang

/// Panjang minimum kata sandi cadangan.
const kMinBackupPassword = 8;

/// Mengembalikan pesan masalah bila kata sandi terlalu lemah, atau null bila boleh dipakai.
String? backupPasswordProblem(String pw) {
  if (pw.length < kMinBackupPassword) return 'Kata sandi cadangan minimal $kMinBackupPassword karakter.';
  if (RegExp(r'^(.)\1+$').hasMatch(pw)) return 'Kata sandi tidak boleh berisi satu karakter yang diulang.';
  return null;
}

bool isEncryptedBackup(String raw) {
  try {
    final j = jsonDecode(raw);
    return j is Map && j['enc'] == 1;
  } catch (_) {
    return false;
  }
}

int _iterationsOf(Map<String, dynamic> j) {
  final kdf = j['kdf'];
  if (kdf is String) {
    final m = RegExp(r'^pbkdf2-sha256-(\d+)$').firstMatch(kdf);
    final n = m == null ? null : int.tryParse(m.group(1)!);
    if (n != null && n >= _minIterations && n <= _maxIterations) return n;
  }
  return _legacyIterations;
}

Future<c.SecretKey> _derive(String password, List<int> salt, int iterations) {
  final kdf = c.Pbkdf2(macAlgorithm: c.Hmac.sha256(), iterations: iterations, bits: 256);
  return kdf.deriveKeyFromPassword(password: password, nonce: salt);
}

/// Enkripsi AES-256-GCM dengan kunci turunan PBKDF2-SHA256 dari kata sandi.
Future<String> encryptBackup(String plain, String password, {int iterations = kBackupIterations}) async {
  final rnd = Random.secure();
  final salt = Uint8List.fromList(List.generate(16, (_) => rnd.nextInt(256)));
  final key = await _derive(password, salt, iterations);
  final box = await c.AesGcm.with256bits().encrypt(utf8.encode(plain), secretKey: key);
  return jsonEncode({
    'app': 'catatan_uang',
    'enc': 1,
    'kdf': 'pbkdf2-sha256-$iterations',
    'salt': base64Encode(salt),
    'data': base64Encode(box.concatenation()),
  });
}

Future<String> decryptBackup(String wrapper, String password) async {
  try {
    final j = jsonDecode(wrapper) as Map<String, dynamic>;
    final salt = base64Decode(j['salt'] as String);
    final key = await _derive(password, salt, _iterationsOf(j));
    final box = c.SecretBox.fromConcatenation(base64Decode(j['data'] as String), nonceLength: 12, macLength: 16);
    final clear = await c.AesGcm.with256bits().decrypt(box, secretKey: key);
    return utf8.decode(clear);
  } catch (_) {
    throw BackupException('Kata sandi salah atau file rusak');
  }
}
