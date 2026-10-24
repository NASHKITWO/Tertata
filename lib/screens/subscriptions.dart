import 'package:flutter/material.dart';
import '../common.dart';
import '../services/subscriptions.dart';

/// Langganan dan tagihan rutin yang terdeteksi otomatis dari catatan pengeluaran.
class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  Future<void> _makeRecurring(BuildContext context, AppState s, Subscription sub) async {
    final ok = await confirmDialog(
      context,
      'Buat transaksi berulang "${sub.name}" ${sub.freq.label.toLowerCase()} sebesar ${rp(sub.amount)}, berikutnya ${tgl(sub.nextDate)}?',
      ok: 'Buat',
      title: 'Jadikan berulang',
    );
    if (!ok) return;
    final wallet = s.wallet(sub.walletId);
    final walletId = (wallet != null && !wallet.archived) ? wallet.id : (s.activeWallets.isNotEmpty ? s.activeWallets.first.id : null);
    if (walletId == null) {
      if (context.mounted) snack(context, 'Buat dompet dulu');
      return;
    }
    await s.saveRecurring(Recurring(
      id: s.uid(),
      type: TxType.expense,
      amount: sub.amount,
      walletId: walletId,
      categoryId: sub.categoryId,
      note: sub.name,
      freq: sub.freq,
      nextDate: sub.nextDate,
      anchorDay: sub.nextDate.day,
    ));
    if (context.mounted) snack(context, '"${sub.name}" dijadwalkan');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final covered = <String>{for (final r in s.recurrings) normalizeMerchant(r.note)};
    final subs = detectSubscriptions(s.txs, alreadyRecurring: covered);
    final monthly = subs.fold<double>(0.0, (a, e) => a + e.monthlyCost);
    String money(num v) => s.hideBalance ? '$currencySymbol••••' : rp(v);

    return Scaffold(
      appBar: AppBar(title: const Text('Langganan')),
      body: subs.isEmpty
          ? const EmptyState(
              icon: Icons.subscriptions_outlined,
              title: 'Belum ada langganan terdeteksi',
              subtitle:
                  'Pengeluaran yang dicatat dengan nama yang sama, nominal mirip, dan berulang tiap bulan atau minggu (minimal 3 kali) akan muncul di sini.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppCard(
                  child: Row(children: [
                    const IconBadge(icon: Icons.autorenew, color: kWarn, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Biaya rutin per bulan', style: Theme.of(context).textTheme.bodySmall),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(money(monthly), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                        ),
                        Text('≈ ${money(monthly * 12)} per tahun', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                ),
                const SectionHeader('Terdeteksi'),
                for (final e in subs)
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconBadge(icon: kIcons[s.cat(e.categoryId)?.icon ?? 20], color: Color(s.cat(e.categoryId)?.color ?? 0xFF9E9E9E)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${e.freq.label} · ${e.count} kali tercatat', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.event_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Perkiraan berikutnya ${relDay(e.nextDate).toLowerCase()}', style: Theme.of(context).textTheme.bodySmall)),
                        TextButton.icon(
                          onPressed: () => _makeRecurring(context, s, e),
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: const Text('Jadikan berulang'),
                        ),
                      ]),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    'Hasil ini perkiraan dari pola catatan Anda dan dihitung di perangkat. Langganan yang sudah punya transaksi berulang tidak ditampilkan lagi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
