import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';

void main() {
  test('splitEach membulatkan ke bawah dan sisa ditanggung pembayar', () {
    expect(splitEach(300000, 3), 100000);
    final each = splitEach(100000, 3);
    expect(each, 33333);
    final mine = 100000 - each * 2;
    expect(mine, 33334);
    expect(mine + each * 2, 100000);
  });

  test('splitEach aman untuk input tidak valid', () {
    expect(splitEach(1000, 0), 0);
    expect(splitEach(0, 4), 0);
  });
}
