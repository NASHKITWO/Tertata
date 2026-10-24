import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';
import 'package:catatan_uang/services/subscriptions.dart';

Tx tx(String id, DateTime d, double amount, String note, {TxType type = TxType.expense, String? recurringId, bool neutral = false}) =>
    Tx(id: id, type: type, amount: amount, walletId: 'w1', date: d, note: note, recurringId: recurringId, neutral: neutral);

void main() {
  final now = DateTime(2026, 10, 20);

  test('normalizeMerchant membuang angka dan tanda baca', () {
    expect(normalizeMerchant('Netflix  Okt-2026!'), 'netflix okt');
    expect(normalizeMerchant('  Spotify 49000 '), 'spotify');
  });

  test('mendeteksi langganan bulanan dengan nominal mirip', () {
    final subs = detectSubscriptions([
      tx('1', DateTime(2026, 8, 5), 54000, 'Netflix'),
      tx('2', DateTime(2026, 9, 5), 54000, 'Netflix'),
      tx('3', DateTime(2026, 10, 5), 54000, 'netflix'),
      tx('4', DateTime(2026, 10, 7), 25000, 'Kopi'),
    ], now: now);
    expect(subs.length, 1);
    expect(subs.first.freq, Freq.monthly);
    expect(subs.first.amount, 54000);
    expect(subs.first.count, 3);
    expect(subs.first.nextDate, DateTime(2026, 11, 5));
    expect(subs.first.yearlyCost, 54000 * 12);
  });

  test('menolak jika kurang dari 3 kali, nominal tidak konsisten, atau sudah berhenti', () {
    expect(detectSubscriptions([tx('1', DateTime(2026, 9, 5), 50000, 'Gym'), tx('2', DateTime(2026, 10, 5), 50000, 'Gym')], now: now), isEmpty);
    expect(
      detectSubscriptions([
        tx('1', DateTime(2026, 8, 5), 10000, 'Listrik'),
        tx('2', DateTime(2026, 9, 5), 90000, 'Listrik'),
        tx('3', DateTime(2026, 10, 5), 250000, 'Listrik'),
      ], now: now),
      isEmpty,
    );
    expect(
      detectSubscriptions([
        tx('1', DateTime(2026, 3, 5), 50000, 'Majalah'),
        tx('2', DateTime(2026, 4, 5), 50000, 'Majalah'),
        tx('3', DateTime(2026, 5, 5), 50000, 'Majalah'),
      ], now: now),
      isEmpty,
    );
  });

  test('mengabaikan transaksi hasil aturan berulang, arus netral, dan catatan yang sudah dijadwalkan', () {
    final rows = [
      tx('1', DateTime(2026, 8, 5), 54000, 'Netflix', recurringId: 'r'),
      tx('2', DateTime(2026, 9, 5), 54000, 'Netflix', recurringId: 'r'),
      tx('3', DateTime(2026, 10, 5), 54000, 'Netflix', recurringId: 'r'),
    ];
    expect(detectSubscriptions(rows, now: now), isEmpty);
    final plain = [for (final t in rows) tx(t.id, t.date, t.amount, 'Netflix')];
    expect(detectSubscriptions(plain, now: now, alreadyRecurring: {'netflix'}), isEmpty);
    expect(detectSubscriptions([for (final t in rows) tx(t.id, t.date, t.amount, 'Netflix', neutral: true)], now: now), isEmpty);
  });

  test('mendeteksi langganan mingguan dan menghitung biaya bulanan', () {
    final subs = detectSubscriptions([
      for (var i = 0; i < 4; i++) tx('$i', DateTime(2026, 9, 22).add(Duration(days: 7 * i)), 20000, 'Laundry'),
    ], now: now);
    expect(subs.length, 1);
    expect(subs.first.freq, Freq.weekly);
    expect(subs.first.monthlyCost, closeTo(20000 * 52 / 12, .01));
  });
}
