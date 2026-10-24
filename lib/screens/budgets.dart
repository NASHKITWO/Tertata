import 'package:flutter/material.dart';
import '../common.dart';
import '../services/budget_plan.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});
  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _edit(BuildContext context, AppState s, {Budget? b}) async {
    final cats = s.cats
        .where((c) => c.isExpense && (b?.categoryId == c.id || !s.budgets.any((x) => x.categoryId == c.id)))
        .toList();
    if (cats.isEmpty) {
      snack(context, 'Semua kategori pengeluaran sudah punya anggaran');
      return;
    }
    String? cid = b?.categoryId ?? cats.first.id;
    var roll = b?.rolloverFrom != null;
    final ctrl = TextEditingController(text: b == null ? '' : angka(b.amount));
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(b == null ? 'Anggaran Baru' : 'Ubah Anggaran'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: cid,
              decoration: fieldDeco(ctx, 'Kategori'),
              items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: b == null ? (v) => set(() => cid = v) : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahFormatter()],
              decoration: fieldDeco(ctx, 'Batas per bulan', prefix: currencySymbol),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bawa sisa ke bulan depan'),
              subtitle: const Text('Sisa anggaran bulan ini menambah batas bulan berikutnya'),
              value: roll,
              onChanged: (v) => set(() => roll = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final a = parseAmount(ctrl.text);
                if (a > 0 && cid != null) {
                  s.saveBudget(Budget(
                    id: b?.id ?? s.uid(),
                    categoryId: cid!,
                    amount: a,
                    rolloverFrom: roll ? (b?.rolloverFrom ?? DateTime(DateTime.now().year, DateTime.now().month)) : null,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  /// Menyusun anggaran otomatis dengan aturan 50/30/20 dari penghasilan bulanan.
  Future<void> _autoPlan(BuildContext context, AppState s) async {
    final now = DateTime.now();
    var sum = 0.0;
    var months = 0;
    for (var i = 1; i <= 3; i++) {
      final v = s.sumBetween(DateTime(now.year, now.month - i), DateTime(now.year, now.month - i + 1), TxType.income);
      if (v > 0) {
        sum += v;
        months++;
      }
    }
    var suggest = months > 0 ? sum / months : s.sumBetween(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), TxType.income);
    suggest = (suggest / planStep(suggest > 0 ? suggest : 1)).round() * planStep(suggest > 0 ? suggest : 1);
    final ctrl = TextEditingController(text: suggest > 0 ? angka(suggest) : '');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anggaran 50/30/20'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('50% untuk kebutuhan, 30% untuk keinginan, 20% untuk ditabung. Batas tiap kategori mengikuti kebiasaan belanja 3 bulan terakhir. Kategori yang sudah punya anggaran tidak diubah.'),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahFormatter()],
            decoration: fieldDeco(ctx, 'Penghasilan per bulan', prefix: currencySymbol),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buat anggaran')),
        ],
      ),
    );
    final income = parseAmount(ctrl.text);
    if (go != true || income <= 0) return;
    final past = s.byCategory(DateTime(now.year, now.month - 3), DateTime(now.year, now.month), TxType.expense);
    final plan = planBudget503020(
      income: income,
      cats: s.cats,
      pastSpend: past,
      skip: {for (final b in s.budgets) b.categoryId},
    );
    for (final p in plan) {
      await s.saveBudget(Budget(id: s.uid(), categoryId: p.categoryId, amount: p.amount));
    }
    if (context.mounted) snack(context, plan.isEmpty ? 'Semua kategori sudah punya anggaran' : '${plan.length} anggaran dibuat. Sisihkan 20% (${rp(income * .2)}) untuk tabungan.');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final isCurrent = sameMonth(now, month);
    final totalLimit = s.budgets.fold(0.0, (a, b) => a + s.budgetLimit(b, month));
    final totalSpent = s.budgets.fold(0.0, (a, b) => a + s.spentCat(b.categoryId, month));
    final ratio = totalLimit == 0 ? 0.0 : totalSpent / totalLimit;
    final color = ratio >= 1 ? kDanger : (ratio >= .8 ? kWarn : kIncome);
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final remaining = totalLimit - totalSpent;

    final sorted = [...s.budgets]
      ..sort((a, b) => (s.spentCat(b.categoryId, month) / s.budgetLimit(b, month)).compareTo(s.spentCat(a.categoryId, month) / s.budgetLimit(a, month)));

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _edit(context, s),
          icon: const Icon(Icons.add),
          label: const Text('Anggaran'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            PeriodNav(
              label: bulan(month),
              onPrev: () => setState(() => month = DateTime(month.year, month.month - 1)),
              onNext: () => setState(() => month = DateTime(month.year, month.month + 1)),
            ),
            const SizedBox(height: 12),
            if (s.cats.any((c) => c.isExpense && !s.budgets.any((b) => b.categoryId == c.id)))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _autoPlan(context, s),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Susun otomatis 50/30/20'),
                  ),
                ),
              ),
            if (s.budgets.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.donut_large_outlined,
                  title: 'Belum ada anggaran',
                  subtitle: 'Tetapkan batas pengeluaran per kategori agar keuangan tetap terkendali.',
                ),
              )
            else ...[
              AppCard(
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          strokeWidth: 10,
                          color: color,
                          backgroundColor: color.soft(.14),
                        ),
                      ),
                      Text('${(ratio * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total anggaran', style: Theme.of(context).textTheme.labelMedium),
                      Text(rp(totalLimit), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Terpakai ${rp(totalSpent)}'),
                      Text(remaining >= 0 ? 'Sisa ${rp(remaining)}' : 'Lebih ${rp(-remaining)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      if (isCurrent && remaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('≈ ${rp(remaining / daysLeft)} / hari aman dibelanjakan',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ]),
                  ),
                ]),
              ),
              for (final b in sorted) _item(context, s, b),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AppState s, Budget b) {
    final c = s.cat(b.categoryId);
    final limit = s.budgetLimit(b, month);
    final spent = s.spentCat(b.categoryId, month);
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final color = ratio >= 1 ? kDanger : (ratio >= .8 ? kWarn : kIncome);
    return AppCard(
      onTap: () => _edit(context, s, b: b),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon: kIcons[c?.icon ?? 20], color: Color(c?.color ?? 0xFF9E9E9E), size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(c?.name ?? 'Kategori', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Text('${(ratio * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDialog(context, 'Hapus anggaran ${c?.name ?? ''}?')) s.deleteBudget(b.id);
            },
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), color: color, backgroundColor: color.soft(.14), minHeight: 9, semanticsLabel: 'Anggaran ${c?.name ?? ''}', semanticsValue: '${(ratio * 100).round()} persen terpakai'),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${rp(spent)} / ${rp(limit)}', style: Theme.of(context).textTheme.bodySmall),
          Text(spent > limit ? 'Lebih ${rp(spent - limit)}' : 'Sisa ${rp(limit - spent)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
        if (limit > b.amount)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Termasuk sisa bulan lalu ${rp(limit - b.amount)}', style: Theme.of(context).textTheme.bodySmall),
          ),
      ]),
    );
  }
}
