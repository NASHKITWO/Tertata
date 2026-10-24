import 'dart:math' show max;
import '../data/models.dart';

/// Kategori kebutuhan pokok untuk aturan 50/30/20; kategori lain dianggap keinginan.
const kNeedNames = <String>{
  'makanan',
  'transportasi',
  'bbm',
  'tagihan',
  'listrik & air',
  'pulsa & internet',
  'kesehatan',
  'pendidikan',
  'rumah',
};

class PlanItem {
  const PlanItem(this.categoryId, this.amount, this.need);
  final String categoryId;
  final double amount;
  final bool need;
}

/// Pembulatan yang masuk akal untuk mata uang bernilai besar (Rp) maupun kecil (\$, €).
double planStep(double income) => income >= 1000000 ? 5000 : (income >= 10000 ? 500 : 1);

/// Membagi 50% penghasilan untuk kebutuhan dan 30% untuk keinginan ke kategori pengeluaran
/// (20% sisanya untuk tabungan, tidak dianggarkan). Bobot mengikuti pengeluaran 3 bulan terakhir
/// ([pastSpend]); kategori yang sudah punya anggaran ([skip]) dilewati.
List<PlanItem> planBudget503020({
  required double income,
  required List<Cat> cats,
  required Map<String?, double> pastSpend,
  Set<String> skip = const {},
}) {
  if (income <= 0) return const [];
  final step = planStep(income);
  final expense = cats.where((c) => c.isExpense && !skip.contains(c.id)).toList();
  final needs = expense.where((c) => kNeedNames.contains(c.name.toLowerCase())).toList();
  final wants = expense.where((c) => !kNeedNames.contains(c.name.toLowerCase())).toList();

  List<PlanItem> share(List<Cat> group, double pool, bool need) {
    if (group.isEmpty || pool <= 0) return const [];
    final spends = [for (final c in group) max(0.0, pastSpend[c.id] ?? 0.0)];
    final total = spends.fold<double>(0.0, (a, b) => a + b);
    // dasar kecil agar kategori tanpa riwayat tetap mendapat jatah
    final base = total > 0 ? total / (group.length * 4) : 1.0;
    final weights = [for (final v in spends) v + base];
    final wsum = weights.fold<double>(0.0, (a, b) => a + b);
    final items = <PlanItem>[];
    for (var i = 0; i < group.length; i++) {
      final raw = pool * weights[i] / wsum;
      final amt = max(step, (raw / step).round() * step);
      items.add(PlanItem(group[i].id, amt, need));
    }
    return items;
  }

  return [...share(needs, income * .5, true), ...share(wants, income * .3, false)];
}
