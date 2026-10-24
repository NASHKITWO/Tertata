import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/services/auto_backup.dart';

void main() {
  group('jadwal', () {
    final now = DateTime(2026, 10, 24, 12);
    test('belum pernah dicadangkan berarti sudah waktunya', () {
      expect(AutoBackup.isDue(null, now, 3), isTrue);
    });
    test('menghormati interval hari', () {
      expect(AutoBackup.isDue(now.subtract(const Duration(days: 2)), now, 3), isFalse);
      expect(AutoBackup.isDue(now.subtract(const Duration(days: 3)), now, 3), isTrue);
      expect(AutoBackup.isDue(now.subtract(const Duration(hours: 23)), now, 1), isFalse);
    });
    test('jam diubah mundur tidak menunda cadangan selamanya', () {
      expect(AutoBackup.isDue(now.add(const Duration(days: 30)), now, 3), isTrue);
    });
  });

  group('nama berkas', () {
    test('nama dibuat dan dikenali', () {
      final n = AutoBackup.fileName(DateTime(2026, 1, 2, 3, 4, 5));
      expect(n, 'tertata_auto_20260102_030405.json');
      expect(AutoBackup.isAutoFile(n), isTrue);
      expect(AutoBackup.isAutoFile('catatan_uang_backup.json'), isFalse);
      expect(AutoBackup.isAutoFile('../tertata_auto_20260102_030405.json'), isFalse);
    });

    test('hanya yang terbaru yang disimpan', () {
      final names = [for (var i = 1; i <= 8; i++) 'tertata_auto_2026010${i}_000000.json', 'lain.txt'];
      final del = AutoBackup.toDelete(names);
      expect(del.length, 3);
      expect(del, containsAll(['tertata_auto_20260101_000000.json', 'tertata_auto_20260102_000000.json', 'tertata_auto_20260103_000000.json']));
      expect(AutoBackup.toDelete(names.take(3).toList()), isEmpty);
    });
  });

  test('menulis berkas dan memangkas yang lama', () async {
    final dir = await Directory.systemTemp.createTemp('tertata_ab_');
    try {
      for (var i = 1; i <= 7; i++) {
        await AutoBackup.writeAndPrune(dir, '{"i":$i}', DateTime(2026, 1, i, 10));
      }
      final files = await AutoBackup.files(dir: dir);
      expect(files.length, AutoBackup.keep);
      expect(files.first.path, endsWith('tertata_auto_20260107_100000.json'));
      expect(await files.first.readAsString(), '{"i":7}');
      expect(dir.listSync().any((e) => e.path.endsWith('.tmp')), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
