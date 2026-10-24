import 'package:flutter/material.dart';
import '../common.dart';
import 'tx_form.dart';

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  double _monthly(Recurring r) => switch (r.freq) {
        Freq.daily => r.amount * 30,
        Freq.weekly => r.amount * 4.345,
        Freq.monthly => r.amount,
        Freq.yearly => r.amount / 12,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final sorted = [...s.recurrings]..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.nextDate.compareTo(b.nextDate);
      });
    final estExp = s.recurrings.where((r) => r.active && r.type == TxType.expense).fold(0.0, (a, r) => a + _monthly(r));
    final estInc = s.recurrings.where((r) => r.active && r.type == TxType.income).fold(0.0, (a, r) => a + _monthly(r));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berulang')),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxFormScreen(newRule: true))),
        icon: const Icon(Icons.add),
        label: const Text('Aturan'),
      ),
      body: sorted.isEmpty
          ? const EmptyState(
              icon: Icons.event_repeat,
              title: 'Belum ada transaksi berulang',
              subtitle: 'Cocok untuk gaji, cicilan, langganan, listrik, dan tagihan rutin lainnya. Dicatat otomatis sesuai jadwal.',
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
              AppCard(
                color: cs.primary.soft(.07),
                child: Row(children: [
                  Expanded(child: _est(context, 'Estimasi pemasukan / bulan', rp(estInc), kIncome)),
                  Expanded(child: _est(context, 'Estimasi pengeluaran / bulan', rp(estExp), kExpense)),
                ]),
              ),
              for (final r in sorted)
                Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => confirmDialog(context, 'Hapus aturan ini? Transaksi yang sudah tercatat tidak ikut terhapus.'),
                  onDismissed: (_) => s.deleteRecurring(r.id),
                  child: AppCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TxFormScreen(rule: r))),
                    child: Opacity(
                      opacity: r.active ? 1 : .5,
                      child: Row(children: [
                        IconBadge(
                          icon: r.type == TxType.transfer ? Icons.swap_horiz : kIcons[s.cat(r.categoryId)?.icon ?? 20],
                          color: r.type == TxType.transfer ? kTransfer : Color(s.cat(r.categoryId)?.color ?? 0xFF64748B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.type == TxType.transfer ? 'Pindah dana' : (s.cat(r.categoryId)?.name ?? 'Tanpa kategori'),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${r.freq.label} · berikutnya ${tgl(r.nextDate)}', style: Theme.of(context).textTheme.bodySmall),
                            if (r.note.isNotEmpty) Text(r.note, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(rp(r.amount),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: r.type == TxType.income ? kIncome : (r.type == TxType.expense ? kExpense : kTransfer))),
                          Switch(
                            value: r.active,
                            onChanged: (v) {
                              r.active = v;
                              s.saveRecurring(r);
                            },
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }

  Widget _est(BuildContext context, String label, String v, Color c) => Column(children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 16))),
      ]);
}
