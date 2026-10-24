import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/services/native_bridge.dart';
import 'package:catatan_uang/services/widget_sync.dart';

void main() {
  test('decodeItems membaca JSON dari native, mengurutkan terbaru dulu, dan membuang yang kosong', () {
    final items = NativeBridge.decodeItems(
      '[{"id":"1-a","pkg":"id.dana","text":"Pembayaran Rp10.000 ke Toko","time":1000},'
      '{"id":"2-b","pkg":"com.bca","text":"Transfer Rp50.000 berhasil","time":3000},'
      '{"id":"3-c","pkg":"x","text":"   ","time":2000}]',
    );
    expect(items.length, 2);
    expect(items.first.id, '2-b');
    expect(items.first.parseText, 'BCA: Transfer Rp50.000 berhasil');
    expect(items.last.appLabel, 'DANA');
  });

  test('decodeItems aman untuk input rusak atau kosong', () {
    expect(NativeBridge.decodeItems(null), isEmpty);
    expect(NativeBridge.decodeItems(''), isEmpty);
    expect(NativeBridge.decodeItems('bukan json'), isEmpty);
    expect(NativeBridge.decodeItems('{"a":1}'), isEmpty);
  });

  test('paket tak dikenal tidak diberi awalan nama aplikasi', () {
    final it = NativeBridge.decodeItems('[{"id":"1","pkg":"com.lain","text":"Rp1.000 masuk","time":1}]').single;
    expect(it.appLabel, isNull);
    expect(it.parseText, 'Rp1.000 masuk');
  });

  test('widget menyembunyikan saldo secara bawaan', () {
    final p = WidgetSync.payload(show: false, balance: 12345678, spent: 100000, perDay: 50000);
    expect(p['balance']!.contains('12'), isFalse);
    expect(p['detail'], 'Ketuk untuk membuka');
    expect(p['perDay'], '');
  });

  test('widget menampilkan angka bila diizinkan', () {
    final p = WidgetSync.payload(show: true, balance: 1500000, spent: 250000, perDay: 40000);
    expect(p['balance'], contains('1.500.000'));
    expect(p['detail'], contains('250.000'));
    expect(p['perDay'], contains('40.000'));
    expect(WidgetSync.payload(show: true, balance: 1, spent: 0, perDay: 0)['perDay'], '');
  });
}
