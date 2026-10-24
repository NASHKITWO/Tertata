import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';

void main() {
  group('nextOccurrence', () {
    test('bulanan menjaga hari jangkar dan menyesuaikan akhir bulan', () {
      final jan31 = DateTime(2026, 1, 31);
      final feb = nextOccurrence(jan31, Freq.monthly, 31);
      expect(feb, DateTime(2026, 2, 28));
      expect(nextOccurrence(feb, Freq.monthly, 31), DateTime(2026, 3, 31));
    });

    test('bulanan melewati pergantian tahun', () {
      expect(nextOccurrence(DateTime(2026, 12, 15), Freq.monthly, 15), DateTime(2027, 1, 15));
    });

    test('mingguan dan harian', () {
      expect(nextOccurrence(DateTime(2026, 3, 30), Freq.weekly, 30), DateTime(2026, 4, 6));
      expect(nextOccurrence(DateTime(2026, 3, 31), Freq.daily, 31), DateTime(2026, 4, 1));
    });

    test('tahunan pada 29 Februari', () {
      expect(nextOccurrence(DateTime(2028, 2, 29), Freq.yearly, 29), DateTime(2029, 2, 28));
    });
  });

  group('Debt', () {
    test('sisa dan status pembayaran', () {
      final d = Debt(id: 'd1', person: 'Budi', amount: 100000, owedToMe: true);
      d.payments = [
        DebtPayment(id: 'p1', debtId: 'd1', amount: 30000, date: DateTime(2026, 1, 1)),
        DebtPayment(id: 'p2', debtId: 'd1', amount: 20000, date: DateTime(2026, 1, 2)),
      ];
      expect(d.paid, 50000);
      expect(d.remaining, 50000);
    });
  });
}
