import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/app_state.dart';
import 'package:catatan_uang/services/backup_crypto.dart';

Map<String, dynamic> good() => {
      'app': 'catatan_uang',
      'version': 3,
      'data': <String, dynamic>{
        'wallets': <dynamic>[
          {'id': 'w1', 'name': 'Tunai', 'type': 'cash', 'initial': 0, 'color': 1, 'icon': 1, 'archived': 0, 'sort': 0},
        ],
        'transactions': <dynamic>[
          {'id': 't1', 'type': 'expense', 'amount': 5000, 'wallet_id': 'w1', 'date': 1, 'note': '', 'created': 1},
        ],
      },
    };

void main() {
  group('validateBackup', () {
    test('cadangan wajar lolos dan tabel yang tidak ada jadi kosong', () {
      final r = AppState.validateBackup(good());
      expect(r['transactions']!.length, 1);
      expect(r['goals'], isEmpty);
    });

    test('menolak app/versi/struktur yang salah', () {
      expect(() => AppState.validateBackup({...good(), 'app': 'lain'}), throwsFormatException);
      expect(() => AppState.validateBackup({...good(), 'version': 99}), throwsFormatException);
      expect(() => AppState.validateBackup({...good(), 'version': null}), throwsFormatException);
      expect(() => AppState.validateBackup({...good(), 'data': 'x'}), throwsFormatException);
    });

    test('menolak baris yang janggal', () {
      Map<String, dynamic> withTx(Map<String, Object?> m) {
        final j = good();
        ((j['data'] as Map)['transactions'] as List)[0] = m;
        return j;
      }

      expect(() => AppState.validateBackup(withTx({'id': 't1', 'type': 'expense', 'amount': -1, 'date': 1})), throwsFormatException);
      expect(() => AppState.validateBackup(withTx({'id': 't1', 'type': 'expense', 'amount': 'abc', 'date': 1})), throwsFormatException);
      expect(() => AppState.validateBackup(withTx({'id': 't1', 'type': 'hack', 'amount': 1, 'date': 1})), throwsFormatException);
      expect(() => AppState.validateBackup(withTx({'id': '', 'type': 'expense', 'amount': 1, 'date': 1})), throwsFormatException);
    });

    test('menolak ID ganda dalam satu tabel', () {
      final j = good();
      final tx = (j['data'] as Map)['transactions'] as List;
      tx.add(Map<String, Object?>.from(tx[0] as Map));
      expect(() => AppState.validateBackup(j), throwsFormatException);
    });
  });

  group('kata sandi & enkripsi cadangan', () {
    test('kata sandi lemah ditolak', () {
      expect(backupPasswordProblem('pendek'), isNotNull);
      expect(backupPasswordProblem('aaaaaaaaaa'), isNotNull);
      expect(backupPasswordProblem('kuda-biru-91'), isNull);
    });

    test('cadangan baru mencatat jumlah putaran di header dan bisa dibuka', () async {
      final enc = await encryptBackup('halo', 'kuda-biru-91', iterations: 20000);
      expect(jsonDecode(enc)['kdf'], 'pbkdf2-sha256-20000');
      expect(await decryptBackup(enc, 'kuda-biru-91'), 'halo');
    });

    test('cadangan lama (100.000 putaran) tetap bisa dibuka', () async {
      final enc = await encryptBackup('lama', 'kuda-biru-91', iterations: 100000);
      expect(await decryptBackup(enc, 'kuda-biru-91'), 'lama');
    });

    test('header kdf yang dimanipulasi tidak membuat crash maupun hang', () async {
      final j = jsonDecode(await encryptBackup('x', 'kuda-biru-91', iterations: 20000)) as Map<String, dynamic>;
      j['kdf'] = 'pbkdf2-sha256-999999999';
      expect(decryptBackup(jsonEncode(j), 'kuda-biru-91'), throwsA(isA<BackupException>()));
    });
  });
}
