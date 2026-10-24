import 'package:flutter/material.dart';
import '../common.dart';
import 'tx_form.dart';

void openTx(BuildContext context, Tx t) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => TxFormScreen(tx: t)));

void openNewTx(BuildContext context, {TxType? type}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => TxFormScreen(preset: type)));

bool isLoanTx(Tx t) => (t.externalId ?? '').startsWith('debt:') || (t.externalId ?? '').startsWith('pay:');

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onTap});
  final Tx tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.cat(tx.categoryId);
    final w = s.wallet(tx.walletId);
    final to = s.wallet(tx.toWalletId);
    final isT = tx.type == TxType.transfer;
    final color = tx.neutral ? kWarn : (isT ? kTransfer : Color(c?.color ?? 0xFF9E9E9E));
    final title = tx.neutral ? (tx.note.isEmpty ? 'Hutang/Piutang' : tx.note) : (isT ? 'Pindah dana' : (c?.name ?? 'Tanpa kategori'));
    final sub = [
      tx.neutral ? '${w?.name ?? '?'} · ${isLoanTx(tx) ? 'hutang/piutang' : 'penyesuaian saldo'}' : (isT ? '${w?.name ?? '?'} → ${to?.name ?? '?'}' : (w?.name ?? '?')),
      if (tx.note.isNotEmpty && !tx.neutral) tx.note,
      if (tx.recurringId != null) 'berulang',
    ].join(' · ');
    final amtColor = switch (tx.type) {
      TxType.income => kIncome,
      TxType.expense => kExpense,
      TxType.transfer => kTransfer,
    };
    final sign = switch (tx.type) {
      TxType.income => '+',
      TxType.expense => '-',
      TxType.transfer => '',
    };
    final shown = tx.neutral ? Theme.of(context).colorScheme.onSurfaceVariant : amtColor;
    return ListTile(
      onTap: onTap ??
          (tx.neutral
              ? () => snack(context, isLoanTx(tx) ? 'Dibuat dari Hutang & Piutang. Ubah lewat menu Hutang & Piutang.' : 'Penyesuaian saldo. Geser ke kiri untuk menghapus.')
              : () => openTx(context, tx)),
      leading: IconBadge(icon: tx.neutral ? (isLoanTx(tx) ? Icons.handshake_outlined : Icons.tune) : (isT ? Icons.swap_horiz : kIcons[c?.icon ?? 20]), color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('$sign${rp(tx.amount)}', style: TextStyle(color: shown, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String q = '';
  TxType? filter;
  String? walletF;
  String? catF;
  bool calendar = false;
  DateTime? day;

  Widget _dayCell(int d, List<double>? v, DateTime today, DateTime? sel, ColorScheme cs) {
    final date = DateTime(month.year, month.month, d);
    final isSel = sel != null && dayOnly(sel) == date;
    final isToday = date == today;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => day = date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSel ? cs.primary.soft(.14) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? cs.primary : (isToday ? cs.primary.soft(.5) : Colors.transparent)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$d', style: TextStyle(fontWeight: isToday ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
          if (v != null && v[1] > 0) Text(rpShort(v[1]), style: const TextStyle(color: kExpense, fontSize: 9, fontWeight: FontWeight.w600)),
          if (v != null && v[0] > 0) Text(rpShort(v[0]), style: const TextStyle(color: kIncome, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _calendarView(AppState s, List<Tx> list) {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday + 6) % 7; // Senin = 0
    final byDay = <int, List<double>>{};
    for (final t in list) {
      if (t.neutral || t.type == TxType.transfer) continue;
      final g = byDay.putIfAbsent(t.date.day, () => [0, 0]);
      if (t.type == TxType.income) {
        g[0] += t.amount;
      } else {
        g[1] += t.amount;
      }
    }
    final today = dayOnly(DateTime.now());
    final sel = (day != null && sameMonth(day!, month)) ? day : null;
    final selTx = sel == null ? <Tx>[] : list.where((t) => dayOnly(t.date) == sel).toList();
    const heads = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
      AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            for (final h in heads) Expanded(child: Center(child: Text(h, style: Theme.of(context).textTheme.labelSmall))),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: .72,
            children: [
              for (var i = 0; i < offset; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++) _dayCell(d, byDay[d], today, sel, cs),
            ],
          ),
        ]),
      ),
      if (sel != null) ...[
        SectionHeader(relDay(sel)),
        if (selTx.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Tidak ada transaksi')))
        else
          AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final t in selTx) TxTile(tx: t)])),
      ] else
        const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Pilih tanggal untuk melihat transaksi'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    final list = s.between(from, to).where((t) {
      if (filter != null && t.type != filter) return false;
      if (walletF != null && t.walletId != walletF && t.toWalletId != walletF) return false;
      if (catF != null && t.categoryId != catF) return false;
      if (q.isNotEmpty) {
        final hay = '${t.note} ${s.cat(t.categoryId)?.name ?? ''} ${s.wallet(t.walletId)?.name ?? ''}'.toLowerCase();
        if (!hay.contains(q.toLowerCase())) return false;
      }
      return true;
    }).toList();

    final groups = <DateTime, List<Tx>>{};
    for (final t in list) {
      groups.putIfAbsent(dayOnly(t.date), () => []).add(t);
    }
    final entries = groups.entries.toList();
    final inc = list.where((t) => t.type == TxType.income && !t.neutral).fold(0.0, (a, t) => a + t.amount);
    final exp = list.where((t) => t.type == TxType.expense && !t.neutral).fold(0.0, (a, t) => a + t.amount);

    return SafeArea(
      child: Column(children: [
        PageTitle('Transaksi', subtitle: 'Masuk ${rpShort(inc)} · Keluar ${rpShort(exp)}'),
        const SizedBox(height: 6),
        PeriodNav(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          label: bulan(month),
          onPrev: () => setState(() => month = DateTime(month.year, month.month - 1)),
          onNext: () => setState(() => month = DateTime(month.year, month.month + 1)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Daftar'), icon: Icon(Icons.view_list_outlined)),
                ButtonSegment(value: true, label: Text('Kalender'), icon: Icon(Icons.calendar_month_outlined)),
              ],
              selected: {calendar},
              onSelectionChanged: (v) => setState(() => calendar = v.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: fieldDeco(context, 'Cari catatan, kategori, dompet', icon: Icons.search),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            for (final e in <(String, TxType?)>[
              ('Semua', null),
              ('Masuk', TxType.income),
              ('Keluar', TxType.expense),
              ('Pindah dana', TxType.transfer),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(e.$1), selected: filter == e.$2, onSelected: (_) => setState(() => filter = e.$2)),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => walletF = v == '_all' ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '_all', child: Text('Semua dompet')),
                for (final w in s.wallets) PopupMenuItem(value: w.id, child: Text(w.name)),
              ],
              child: Chip(
                avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: Text(walletF == null ? 'Dompet' : (s.wallet(walletF)?.name ?? 'Dompet')),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => catF = v == '_all' ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '_all', child: Text('Semua kategori')),
                for (final c in s.cats) PopupMenuItem(value: c.id, child: Text('${c.name} (${c.isExpense ? 'keluar' : 'masuk'})')),
              ],
              child: Chip(
                avatar: const Icon(Icons.category_outlined, size: 16),
                label: Text(catF == null ? 'Kategori' : (s.cat(catF)?.name ?? 'Kategori')),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('+ ${rp(inc)}', style: const TextStyle(color: kIncome, fontWeight: FontWeight.w700)),
            Text('${list.length} transaksi', style: Theme.of(context).textTheme.bodySmall),
            Text('- ${rp(exp)}', style: const TextStyle(color: kExpense, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: calendar
              ? _calendarView(s, list)
              : entries.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Tidak ada transaksi',
                  subtitle: 'Ubah filter atau catat transaksi baru.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final day = entries[i].key;
                    final items = entries[i].value;
                    final net = items.fold(0.0, (a, t) {
                      if (t.neutral) return a;
                      if (t.type == TxType.income) return a + t.amount;
                      if (t.type == TxType.expense) return a - t.amount;
                      return a;
                    });
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(children: [
                            Expanded(
                              child: Text(relDay(day),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
                            ),
                            Text('${net >= 0 ? '+' : '-'}${rp(net.abs())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: net >= 0 ? kIncome : kExpense)),
                          ]),
                        ),
                        for (final t in items) ...[
                          if (!identical(t, items.first)) const Divider(indent: 72, endIndent: 16),
                          Dismissible(
                            key: ValueKey(t.id),
                            direction: (t.neutral && isLoanTx(t)) ? DismissDirection.none : DismissDirection.endToStart,
                            background: Container(
                              color: kDanger,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              final removed = await s.deleteTx(t.id);
                              if (removed != null && context.mounted) {
                                undoSnack(context, 'Transaksi dihapus', () => s.saveTx(removed));
                              }
                            },
                            child: TxTile(tx: t),
                          ),
                        ],
                        const SizedBox(height: 4),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
