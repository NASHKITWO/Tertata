import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/data/models.dart';
import 'package:catatan_uang/services/budget_plan.dart';

Cat c(String id, String name, {bool expense = true}) => Cat(id: id, name: name, isExpense: expense, color: 0, icon: 0);

void main() {
  final cats = [c('a', 'Makanan'), c('b', 'Transportasi'), c('c', 'Hiburan'), c('d', 'Belanja'), c('e', 'Gaji', expense: false)];

  test('membagi 50% kebutuhan dan 30% keinginan, tanpa kategori pemasukan', () {
    final plan = planBudget503020(income: 10000000, cats: cats, pastSpend: const {});
    expect(plan.map((e) => e.categoryId).toSet(), {'a', 'b', 'c', 'd'});
    final needs = plan.where((e) => e.need).fold<double>(0, (a, e) => a + e.amount);
    final wants = plan.where((e) => !e.need).fold<double>(0, (a, e) => a + e.amount);
    expect(needs, closeTo(5000000, 10000));
    expect(wants, closeTo(3000000, 10000));
  });

  test('bobot mengikuti pengeluaran lampau dan kategori yang dilewati tidak dibuat', () {
    final plan = planBudget503020(income: 10000000, cats: cats, pastSpend: {'a': 3000000, 'b': 1000000}, skip: {'c'});
    final a = plan.firstWhere((e) => e.categoryId == 'a').amount;
    final b = plan.firstWhere((e) => e.categoryId == 'b').amount;
    expect(a, greaterThan(b));
    expect(plan.any((e) => e.categoryId == 'c'), isFalse);
  });

  test('penghasilan nol atau negatif tidak menghasilkan rencana', () {
    expect(planBudget503020(income: 0, cats: cats, pastSpend: const {}), isEmpty);
    expect(planBudget503020(income: -5, cats: cats, pastSpend: const {}), isEmpty);
  });

  test('langkah pembulatan menyesuaikan besar penghasilan', () {
    expect(planStep(5000000), 5000);
    expect(planStep(50000), 500);
    expect(planStep(500), 1);
  });
}
