import 'package:flutter/material.dart';
import '../common.dart';
import 'transactions.dart';

/// Wawasan: pola belanja mingguan, perubahan kategori, dan pengeluaran terbesar.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _daysFull = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = dayOnly(now);
    final m0 = DateTime(now.year, now.month);
    final m1 = DateTime(now.year, now.month + 1);
    final p0 = DateTime(now.year, now.month - 1);

    if (s.txs.isEmpty) {
      return const EmptyState(
        icon: Icons.lightbulb_outline,
        title: 'Wawasan muncul setelah ada transaksi',
        subtitle: 'Catat beberapa transaksi dan aplikasi akan menunjukkan pola belanja Anda.',
      );
    }

    // pola per hari dalam seminggu (8 minggu terakhir)
    final wFrom = DateTime(today.year, today.month, today.day - 55);
    final wTo = DateTime(today.year, today.month, today.day + 1);
    final sums = List<double>.filled(7, 0.0);
    for (final t in s.between(wFrom, wTo)) {
      if (t.type == TxType.expense && !t.neutral) sums[t.date.weekday - 1] += t.amount;
    }
    final avg = [for (final v in sums) v / 8];
    var maxV = 0.0;
    var maxI = 0;
    for (var i = 0; i < 7; i++) {
      if (avg[i] > maxV) {
        maxV = avg[i];
        maxI = i;
      }
    }

    // ringkasan bulan ini
    final monthTx = s.between(m0, m1).where((t) => t.type == TxType.expense && !t.neutral).toList();
    final spentDays = <DateTime>{for (final t in monthTx) dayOnly(t.date)};
    final noSpend = now.day - spentDays.length;
    final exp = s.sumBetween(m0, m1, TxType.expense);
    final dailyAvg = now.day == 0 ? 0.0 : exp / now.day;
    final biggest = ([...monthTx]..sort((a, b) => b.amount.compareTo(a.amount))).take(5).toList();

    // perubahan kategori vs bulan lalu
    final cur = s.byCategory(m0, m1, TxType.expense);
    final prev = s.byCategory(p0, m0, TxType.expense);
    final keys = <String?>{...cur.keys, ...prev.keys}.toList();
    final changes = <MapEntry<String?, double>>[
      for (final k in keys) MapEntry<String?, double>(k, (cur[k] ?? 0.0) - (prev[k] ?? 0.0)),
    ]..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(children: [
          Expanded(child: _stat(context, Icons.today_outlined, 'Rata-rata harian', s.hideBalance ? '$currencySymbol••••' : rp(dailyAvg), cs.primary)),
          const SizedBox(width: 10),
          Expanded(child: _stat(context, Icons.celebration_outlined, 'Hari tanpa belanja', '${noSpend < 0 ? 0 : noSpend} hari', kIncome)),
        ]),
        const SizedBox(height: 12),
        const SectionHeader('Pola belanja mingguan'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              maxV > 0 ? 'Anda paling banyak berbelanja di hari ${_daysFull[maxI]}.' : 'Belum ada pengeluaran dalam 8 minggu terakhir.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Rata-rata per hari selama 8 minggu terakhir', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: maxV == 0 ? .04 : (avg[i] / maxV).clamp(.04, 1.0).toDouble(),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: i == maxI && maxV > 0 ? cs.primary : cs.primary.soft(.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_days[i], style: TextStyle(fontSize: 11, fontWeight: i == maxI ? FontWeight.w700 : FontWeight.w500, color: cs.onSurfaceVariant)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        if (changes.isNotEmpty) ...[
          const SectionHeader('Dibanding bulan lalu'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              for (final e in changes.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    IconBadge(icon: kIcons[s.cat(e.key)?.icon ?? 20], color: Color(s.cat(e.key)?.color ?? 0xFF9E9E9E), size: 34),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.cat(e.key)?.name ?? 'Tanpa kategori', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Icon(e.value > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 15, color: e.value > 0 ? kExpense : kIncome),
                    const SizedBox(width: 4),
                    Text(
                      s.hideBalance ? '••••' : rp(e.value.abs()),
                      style: TextStyle(fontWeight: FontWeight.w700, color: e.value > 0 ? kExpense : kIncome, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
        if (biggest.isNotEmpty) ...[
          const SectionHeader('Pengeluaran terbesar bulan ini'),
          AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final t in biggest) TxTile(tx: t)])),
        ],
      ],
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label, String value, Color c) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: icon, color: c, size: 34),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
      ]),
    );
  }
}
