import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/core/calc.dart';

void main() {
  group('evalExpression', () {
    test('hitungan dasar dan urutan operator', () {
      expect(evalExpression('2+3'), 5);
      expect(evalExpression('2+3*4'), 14);
      expect(evalExpression('(2+3)*4'), 20);
      expect(evalExpression('100-30-20'), 50);
      expect(evalExpression('100/4/5'), 5);
    });

    test('format angka Indonesia: titik ribuan, koma desimal', () {
      expect(evalExpression('25.000+7.500'), 32500);
      expect(evalExpression('1.000.000-250.000'), 750000);
      expect(evalExpression('2,5*4'), 10);
    });

    test('simbol alternatif dan spasi', () {
      expect(evalExpression('25.000 + 7.500 × 2'), 40000);
      expect(evalExpression('9 ÷ 3'), 3);
      expect(evalExpression('3x4'), 12);
      expect(evalExpression('12:4'), 3);
    });

    test('minus dan plus unari', () {
      expect(evalExpression('-5+10'), 5);
      expect(evalExpression('10*-2'), -20);
      expect(evalExpression('+7'), 7);
    });

    test('ekspresi tidak valid mengembalikan null', () {
      expect(evalExpression(''), isNull);
      expect(evalExpression('   '), isNull);
      expect(evalExpression('2+'), isNull);
      expect(evalExpression('*3'), isNull);
      expect(evalExpression('(2+3'), isNull);
      expect(evalExpression('2+3)'), isNull);
      expect(evalExpression('abc'), isNull);
      expect(evalExpression('2++'), isNull);
      expect(evalExpression('5/0'), isNull);
      expect(evalExpression('1/(2-2)'), isNull);
    });

    test('masukan terlalu panjang ditolak tanpa crash', () {
      expect(evalExpression('(' * 200 + '1' + ')' * 200), isNull);
      expect(evalExpression('9' * 100), isNull);
    });
  });
}
