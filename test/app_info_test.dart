import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/core/app_info.dart';

void main() {
  test('kAppVersion sama dengan versi di pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final v = line.replaceFirst('version:', '').trim().split('+').first;
    expect(kAppVersion, v, reason: 'Ubah kAppVersion di lib/core/app_info.dart bersama pubspec.yaml');
  });
}
