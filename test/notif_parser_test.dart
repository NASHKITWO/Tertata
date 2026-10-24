import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';
import 'package:catatan_uang/services/notif_parser.dart';

void main() {
  final now = DateTime(2026, 10, 20);

  test('transfer keluar: nominal, lawan transaksi, dan saldo diabaikan', () {
    final g = parseNotification('BCA: Transfer BI-FAST berhasil Rp 150.000 ke BUDI SANTOSO. Saldo Rp 1.200.000', now: now)!;
    expect(g.type, TxType.expense);
    expect(g.amount, 150000);
    expect(g.walletHint, 'bca');
    expect(g.note, 'Transfer ke Budi Santoso');
  });

  test('pembayaran e-wallet ke merchant', () {
    final g = parseNotification('GoPay: Pembayaran Rp25.000 ke Kopi Kenangan berhasil', now: now)!;
    expect(g.type, TxType.expense);
    expect(g.amount, 25000);
    expect(g.walletHint, 'gopay');
    expect(g.merchant, 'Kopi Kenangan');
  });

  test('dana masuk dikenali sebagai pemasukan', () {
    final g = parseNotification('Anda menerima Rp 500.000,00 dari ANDI. Saldo Rp 2.000.000', now: now)!;
    expect(g.type, TxType.income);
    expect(g.amount, 500000);
    expect(g.note, 'Dari Andi');
  });

  test('nominal gaya Inggris dan tanggal dd/mm/yyyy', () {
    final g = parseNotification('Payment IDR 1,250,000.00 at TOKOPEDIA on 05/10/2026', now: now)!;
    expect(g.amount, 1250000);
    expect(g.date, DateTime(2026, 10, 5));
  });

  test('top up dianggap pindah dana', () {
    final g = parseNotification('Top up DANA berhasil Rp100.000 dari BCA', now: now)!;
    expect(g.type, TxType.transfer);
    expect(g.toHint, 'dana');
    expect(g.walletHint, 'bca');
    expect(g.amount, 100000);
  });

  test('tanpa nominal rupiah mengembalikan null; biaya admin dan saldo dilewati', () {
    expect(parseNotification('Kode OTP Anda 123456', now: now), isNull);
    expect(parseNotification('', now: now), isNull);
    final g = parseNotification('Biaya admin Rp 2.500 Pembayaran Rp 75.000 ke PLN', now: now)!;
    expect(g.amount, 75000);
  });

  test('memecah beberapa notifikasi dengan baris kosong', () {
    expect(splitNotifications('A Rp1.000\n\n\nB Rp2.000\n  \nC').length, 3);
  });
}
