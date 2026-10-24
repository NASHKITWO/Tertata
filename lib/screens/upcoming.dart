import 'package:flutter/material.dart';
import '../common.dart';
import '../services/insights.dart';

class UpcomingTile extends StatelessWidget {
  const UpcomingTile({super.key, required this.item, this.showDate = false});
  final UpcomingItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final c = item.overdue ? kDanger : item.color;
    return ListTile(
      leading: IconBadge(icon: item.icon, color: c),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(showDate ? '${relDay(item.date)} · ${item.subtitle}' : item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        s.hideBalance ? '$currencySymbol••••' : '${item.income ? '+' : '-'}${rp(item.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: item.income ? kIncome : cs.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class UpcomingPage extends StatelessWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final items = upcoming(s, days: 30);
    final out = items.where((e) => !e.income).fold<double>(0.0, (a, e) => a + e.amount);
    final inn = items.where((e) => e.income).fold<double>(0.0, (a, e) => a + e.amount);

    final groups = <DateTime, List<UpcomingItem>>{};
    for (final e in items) {
      groups.putIfAbsent(e.date, () => <UpcomingItem>[]).add(e);
    }
    final keys = groups.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Akan Datang')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Tidak ada yang jatuh tempo',
              subtitle: '30 hari ke depan bebas dari tagihan, transaksi berulang, dan hutang yang dijadwalkan.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(children: [
                  Expanded(child: _total(context, 'Akan keluar', out, kExpense, Icons.north_east, s.hideBalance)),
                  const SizedBox(width: 10),
                  Expanded(child: _total(context, 'Akan masuk', inn, kIncome, Icons.south_west, s.hideBalance)),
                ]),
                const SizedBox(height: 12),
                for (final k in keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text(relDay(k), style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final e in groups[k]!) UpcomingTile(item: e)])),
                ],
              ],
            ),
    );
  }

  Widget _total(BuildContext context, String label, double v, Color c, IconData icon, bool hide) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: icon, color: c, size: 34),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(hide ? '$currencySymbol••••' : rp(v), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ),
      ]),
    );
  }
}
