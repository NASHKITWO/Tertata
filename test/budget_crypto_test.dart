import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';
import 'package:catatan_uang/services/backup_crypto.dart';

void main() {
  test('rolloverLimit membawa sisa dan tidak pernah negatif', () {
    expect(rolloverLimit(1000, []), 1000);
    expect(rolloverLimit(1000, [700]), 1300);
    expect(rolloverLimit(1000, [700, 1500]), 1000);
    expect(rolloverLimit(1000, [1200]), 1000);
    expect(rolloverLimit(1000, [0, 0]), 3000);
  });

  test('cadangan terenkripsi: bolak-balik dan salah sandi', () async {
    const plain = '{"app":"catatan_uang","data":{}}';
    final enc = await encryptBackup(plain, 'rahasia');
    expect(isEncryptedBackup(enc), true);
    expect(isEncryptedBackup(plain), false);
    expect(await decryptBackup(enc, 'rahasia'), plain);
    expect(decryptBackup(enc, 'salah'), throwsA(isA<BackupException>()));
  });
}
