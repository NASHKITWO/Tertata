import 'package:flutter/material.dart';
import '../common.dart';
import '../services/insights.dart';
import 'auto_capture.dart';
import 'health.dart';
import 'paste_notif.dart';
import 'upcoming.dart';
import 'transactions.dart';
import 'wallets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  String _money(AppState s, num v) => s.hideBalance ? '$currencySymbol••••••' : rp(v);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = dayOnly(now);
    final m0 = DateTime(now.year, now.month);
    final m1 = DateTime(now.year, now.month + 1);
    final p0 = DateTime(now.year, now.month - 1);
    final inc = s.sumBetween(m0, m1, TxType.income);
    final exp = s.sumBetween(m0, m1, TxType.expense);
    final prevExp = s.sumBetween(p0, m0, TxType.expense);

    String? insight;
    if (prevExp > 0 && exp > 0) {
      final ch = (exp - prevExp) / prevExp * 100;
      insight = 'Pengeluaran bulan ini ${ch >= 0 ? 'naik' : 'turun'} ${ch.abs().toStringAsFixed(0)}% dibanding bulan lalu.';
    } else if (inc > 0 && exp > 0) {
      insight = 'Anda sudah memakai ${(exp / inc * 100).toStringAsFixed(0)}% dari pemasukan bulan ini.';
    }

    final budgets = [...s.budgets]
      ..sort((a, b) => (s.spentCat(b.categoryId, now) / s.budgetLimit(b, now)).compareTo(s.spentCat(a.categoryId, now) / s.budgetLimit(a, now)));

    final attention = <String>[];
    for (final d in s.debts.where((d) => !d.settled && d.due != null)) {
      final days = dayOnly(d.due!).difference(today).inDays;
      if (days <= 3) {
        final when = days < 0 ? 'terlambat' : relDay(d.due!).toLowerCase();
        attention.add('${d.owedToMe ? 'Piutang' : 'Hutang'} ${d.person} · $when');
      }
    }
    for (final r in s.recurrings.where((r) => r.active && r.type == TxType.expense)) {
      final days = dayOnly(r.nextDate).difference(today).inDays;
      if (days >= 0 && days <= 3) {
        attention.add('${s.cat(r.categoryId)?.name ?? 'Tagihan'} ${rp(r.amount)} · ${relDay(r.nextDate).toLowerCase()}');
      }
    }
    for (final b in budgets) {
      final limit = s.budgetLimit(b, now);
      if (limit <= 0) continue;
      final ratio = s.spentCat(b.categoryId, now) / limit;
      final name = s.cat(b.categoryId)?.name ?? 'Kategori';
      if (ratio >= 1) {
        attention.add('Anggaran $name terlewati (${(ratio * 100).toStringAsFixed(0)}%)');
      } else if (ratio >= .8) {
        attention.add('Anggaran $name sudah ${(ratio * 100).toStringAsFixed(0)}%, tersisa ${DateTime(now.year, now.month + 1, 0).day - now.day + 1} hari');
      }
    }
    if (s.txs.length >= 20 && (s.lastBackup == null || now.difference(s.lastBackup!).inDays > 30)) {
      attention.add('Belum ada cadangan data dalam 30 hari terakhir (Lainnya > Pengaturan > Data)');
    }

    // Denyut keuangan bulan ini: sisa aman per hari + kategori terbesar.
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final totalLimit = budgets.fold<double>(0.0, (a, b) => a + s.budgetLimit(b, now));
    final budgetSpent = budgets.fold<double>(0.0, (a, b) => a + s.spentCat(b.categoryId, now));
    final hasBudget = totalLimit > 0;
    final remaining = hasBudget ? totalLimit - budgetSpent : inc - exp;
    final perDay = remaining > 0 ? remaining / daysLeft : 0.0;
    final usedRatio = hasBudget ? budgetSpent / totalLimit : (inc > 0 ? exp / inc : 0.0);
    final topCats = s.byCategory(m0, m1, TxType.expense).entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final health = computeHealth(s);
    final soon = upcoming(s, days: 14).take(3).toList();
    final recentTxs = s.recent.toList();

    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_greeting()} · ${tglHari(now)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Tertata', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6)),
              ]),
            ),
            IconButton(
              tooltip: s.hideBalance ? 'Tampilkan saldo' : 'Sembunyikan saldo',
              icon: Icon(s.hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => s.setHide(!s.hideBalance),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: fillOf(context),
              borderRadius: BorderRadius.circular(26),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? null
                  : [BoxShadow(color: fillOf(context).soft(.28), blurRadius: 26, offset: const Offset(0, 12))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsPage())),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total saldo', style: TextStyle(color: onFillOf(context).soft(.8), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _money(s, s.netWorth),
                        style: TextStyle(
                          color: onFillOf(context),
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(color: onFillOf(context).soft(.12), borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        Expanded(child: _flow(context, Icons.south_west, 'Masuk bulan ini', _money(s, inc))),
                        Expanded(child: _flow(context, Icons.north_east, 'Keluar bulan ini', _money(s, exp))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _quick(Icons.north_east, 'Keluar', kExpense, () => openNewTx(context, type: TxType.expense)),
            const SizedBox(width: 10),
            _quick(Icons.south_west, 'Masuk', kIncome, () => openNewTx(context, type: TxType.income)),
            const SizedBox(width: 10),
            _quick(Icons.swap_horiz, 'Pindah', kTransfer, () => openNewTx(context, type: TxType.transfer)),
            const SizedBox(width: 10),
            _quick(Icons.content_paste_go_outlined, 'Tempel', cs.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasteNotifPage()))),
          ]),
          const SizedBox(height: 16),
          const InboxBanner(),
          if (attention.isNotEmpty)
            AppCard(
              color: kWarn.soft(.07),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  IconBadge(icon: Icons.notifications_none, color: kWarn, size: 30),
                  SizedBox(width: 10),
                  Text('Perlu perhatian', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                for (final t in attention.take(4)) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t)),
              ]),
            ),
          if (inc > 0 || exp > 0) _pulse(context, s, inc, exp, hasBudget, remaining, perDay, daysLeft, usedRatio, topCats, m0, m1, insight: insight),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: AppCard(
                  margin: EdgeInsets.zero,
                  onTap: () => onTab(2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBadge(icon: Icons.chat_bubble_outline_rounded, color: cs.primary, size: 36),
                    const SizedBox(height: 10),
                    const Text('Asisten', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Catat dengan kalimat atau tanya analisis', style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  margin: EdgeInsets.zero,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthPage())),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RingGauge(semanticLabel: 'Skor kesehatan keuangan', value: health.score / 100, color: health.color, label: '${health.score}', size: 44),
                    const SizedBox(height: 10),
                    const Text('Kesehatan', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(health.grade, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (soon.isNotEmpty) ...[
            SectionHeader('Akan datang', action: 'Semua', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpcomingPage()))),
            AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final e in soon) UpcomingTile(item: e, showDate: true)])),
          ],
          if (budgets.isNotEmpty) ...[
            SectionHeader('Anggaran bulan ini', action: 'Semua', onAction: () => onTab(3)),
            AppCard(child: Column(children: [for (final b in budgets.take(3)) _budgetRow(context, s, b, now)])),
          ],
          SectionHeader('Transaksi terakhir', action: s.txs.isEmpty ? null : 'Semua', onAction: () => onTab(1)),
          if (s.txs.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi',
                subtitle: 'Tekan "Catat" atau tulis ke asisten, mis. "kopi 25rb".',
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < recentTxs.length; i++) ...[
                  if (i > 0) const Divider(indent: 72, endIndent: 16),
                  TxTile(tx: recentTxs[i]),
                ],
              ]),
            ),
        ],
      ),
    ));
  }

  Widget _pulse(BuildContext context, AppState s, double inc, double exp, bool hasBudget, double remaining, double perDay,
      int daysLeft, double usedRatio, List<MapEntry<String?, double>> topCats, DateTime m0, DateTime m1,
      {String? insight}) {
    final cs = Theme.of(context).colorScheme;
    final over = remaining < 0;
    final ringColor = usedRatio >= 1 ? kDanger : (usedRatio >= .8 ? kWarn : kIncome);
    final saveRate = inc > 0 ? (inc - exp) / inc * 100 : null;
    final total = topCats.fold<double>(0.0, (a, e) => a + e.value);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RingGauge(semanticLabel: 'Pemakaian anggaran', value: usedRatio, color: ringColor, label: '${(usedRatio * 100).clamp(0, 999).toStringAsFixed(0)}%'),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(over ? 'Melewati batas' : 'Aman dipakai per hari', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  over ? _money(s, -remaining) : _money(s, perDay),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: over ? kDanger : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                over
                    ? (hasBudget ? 'dari total anggaran bulan ini' : 'pengeluaran melebihi pemasukan')
                    : 'untuk $daysLeft hari lagi · ${hasBudget ? 'dari sisa anggaran' : 'dari sisa pemasukan'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ]),
        if (saveRate != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SoftChip(
              text: saveRate >= 0 ? 'Tabungan ${saveRate.toStringAsFixed(0)}% dari pemasukan' : 'Defisit ${(-saveRate).toStringAsFixed(0)}%',
              color: saveRate >= 20 ? kIncome : (saveRate >= 0 ? kWarn : kDanger),
              icon: saveRate >= 0 ? Icons.savings_outlined : Icons.warning_amber_rounded,
            ),
          ]),
        ],
        if (insight != null) ...[
          const SizedBox(height: 10),
          Text(insight, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (topCats.isNotEmpty && total > 0) ...[
          const SizedBox(height: 14),
          Text('Pengeluaran terbesar', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                for (final e in topCats.take(4))
                  Expanded(
                    flex: (e.value / total * 1000).round().clamp(1, 1000).toInt(),
                    child: Container(color: Color(s.cat(e.key)?.color ?? 0xFF9E9E9E)),
                  ),
                if (topCats.length > 4)
                  Expanded(
                    flex: (topCats.skip(4).fold<double>(0.0, (a, e) => a + e.value) / total * 1000).round().clamp(1, 1000).toInt(),
                    child: Container(color: cs.outlineVariant),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          for (final e in topCats.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(s.cat(e.key)?.color ?? 0xFF9E9E9E), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.cat(e.key)?.name ?? 'Tanpa kategori', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${(e.value / total * 100).toStringAsFixed(0)}%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(width: 10),
                Text(_money(s, e.value), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _flow(BuildContext context, IconData icon, String label, String value) {
    final fg = onFillOf(context);
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: fg.soft(.16), shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: fg.soft(.7), fontSize: 11)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ),
    ]);
  }

  Widget _quick(IconData icon, String label, Color color, VoidCallback onTap, {Widget? leading}) {
    return Expanded(
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: onTap,
        child: Column(children: [
          leading ?? IconBadge(icon: icon, color: color, size: 44),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _budgetRow(BuildContext context, AppState s, Budget b, DateTime now) {
    final c = s.cat(b.categoryId);
    final spent = s.spentCat(b.categoryId, now);
    final limit = s.budgetLimit(b, now);
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final color = ratio >= 1 ? kDanger : (ratio >= .8 ? kWarn : kIncome);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [
          IconBadge(icon: kIcons[c?.icon ?? 20], color: Color(c?.color ?? 0xFF9E9E9E), size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(c?.name ?? 'Kategori', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${rpShort(spent)} / ${rpShort(limit)}', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), color: color, backgroundColor: color.soft(.14), minHeight: 7, semanticsLabel: 'Anggaran ${c?.name ?? ''}', semanticsValue: '${(ratio * 100).round()} persen terpakai'),
        ),
      ]),
    );
  }
}
