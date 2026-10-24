import 'package:flutter/material.dart';
import '../common.dart';
import '../services/smart.dart';

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget tab(bool owedToMe) {
      final items = s.debts.where((d) => d.owedToMe == owedToMe).toList()
        ..sort((a, b) {
          if (a.settled != b.settled) return a.settled ? 1 : -1;
          return (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100));
        });
      final outstanding = items.where((d) => !d.settled).fold(0.0, (a, d) => a + d.remaining);
      final color = owedToMe ? kIncome : kExpense;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        AppCard(
          color: color.soft(.08),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(owedToMe ? 'Total piutang (belum diterima)' : 'Total hutang (belum dibayar)',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(rp(outstanding), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
        if (items.isEmpty)
          const SizedBox(
            height: 260,
            child: EmptyState(icon: Icons.handshake_outlined, title: 'Belum ada catatan', subtitle: 'Tekan tombol + untuk menambah.'),
          ),
        for (final d in items) _card(context, s, d),
      ]);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hutang & Piutang'),
          actions: [
            IconButton(tooltip: 'Patungan', icon: const Icon(Icons.groups_outlined), onPressed: () => splitDialog(context)),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Hutang saya'), Tab(text: 'Piutang')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
          heroTag: null,
            onPressed: () => debtDialog(ctx, owedToMe: DefaultTabController.of(ctx).index == 1),
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
        ),
        body: TabBarView(children: [tab(false), tab(true)]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState s, Debt d) {
    final color = d.owedToMe ? kIncome : kExpense;
    final ratio = d.amount == 0 ? 0.0 : (d.paid / d.amount).clamp(0.0, 1.0);
    final overdue = !d.settled && d.due != null && d.due!.isBefore(dayOnly(DateTime.now()));
    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _DebtSheet(debtId: d.id),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon: Icons.person_outline, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.person, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (d.due != null)
                Text(
                  'Jatuh tempo ${tgl(d.due!)}${overdue ? ' · terlambat' : ''}',
                  style: TextStyle(fontSize: 12, color: overdue ? kDanger : null),
                ),
            ]),
          ),
          if (d.settled)
            const Chip(label: Text('Lunas'), avatar: Icon(Icons.check_circle, color: kIncome, size: 18))
          else
            Text(rp(d.remaining), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio, color: color, backgroundColor: color.soft(.14), minHeight: 8),
        ),
        const SizedBox(height: 6),
        Text('${rp(d.paid)} dari ${rp(d.amount)}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

Future<void> debtDialog(BuildContext context, {Debt? d, bool owedToMe = false}) async {
  final s = AppScope.of(context);
  final person = TextEditingController(text: d?.person ?? '');
  final amount = TextEditingController(text: d == null ? '' : angka(d.amount));
  final note = TextEditingController(text: d?.note ?? '');
  DateTime? due = d?.due;
  var mine = d?.owedToMe ?? owedToMe;
  String? wid;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(d == null ? 'Catatan Baru' : 'Ubah Catatan'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (d == null)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Hutang saya')),
                  ButtonSegment(value: true, label: Text('Piutang')),
                ],
                selected: {mine},
                onSelectionChanged: (v) => set(() => mine = v.first),
              ),
            if (d == null) const SizedBox(height: 12),
            TextField(controller: person, decoration: fieldDeco(ctx, 'Nama orang', icon: Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahFormatter()],
              decoration: fieldDeco(ctx, 'Jumlah', prefix: currencySymbol),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(due == null ? 'Jatuh tempo (opsional)' : tgl(due!)),
              onPressed: () async {
                final x = await showDatePicker(
                  context: ctx,
                  initialDate: due ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (x != null) set(() => due = x);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: note, decoration: fieldDeco(ctx, 'Catatan', icon: Icons.notes)),
            if (d == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: wid,
                isExpanded: true,
                decoration: fieldDeco(ctx, mine ? 'Uang keluar dari dompet' : 'Uang masuk ke dompet'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Jangan catat di dompet')),
                  for (final w in s.activeWallets) DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => set(() => wid = v),
              ),
              const SizedBox(height: 6),
              Text(
                'Jika dipilih, saldo dompet ikut berubah tetapi tidak dihitung sebagai pemasukan/pengeluaran.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final a = parseAmount(amount.text);
              if (person.text.trim().isEmpty || a <= 0) return;
              final nd = Debt(
                id: d?.id ?? s.uid(),
                person: person.text.trim(),
                amount: a,
                owedToMe: mine,
                due: due,
                note: note.text.trim(),
                created: d?.created,
              );
              if (d != null) {
                nd.payments = d.payments;
                s.saveDebt(nd);
              } else {
                s.createDebt(nd, walletId: wid);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

class _DebtSheet extends StatelessWidget {
  const _DebtSheet({required this.debtId});
  final String debtId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final matches = s.debts.where((x) => x.id == debtId);
    if (matches.isEmpty) return const SizedBox(height: 80);
    final d = matches.first;
    final color = d.owedToMe ? kIncome : kExpense;

    Future<void> pay() async {
      final ctrl = TextEditingController(text: angka(d.remaining));
      final note = TextEditingController();
      String? wid;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: Text(d.owedToMe ? 'Catat penerimaan' : 'Catat pembayaran'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahFormatter()],
                  decoration: fieldDeco(ctx, 'Nominal', prefix: currencySymbol),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: fieldDeco(ctx, 'Catatan (opsional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: wid,
                  isExpanded: true,
                  decoration: fieldDeco(ctx, d.owedToMe ? 'Uang masuk ke dompet' : 'Uang keluar dari dompet'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Jangan catat di dompet')),
                    for (final w in s.activeWallets) DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => set(() => wid = v),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: () {
                  final a = parseAmount(ctrl.text);
                  if (a <= 0) return;
                  s.addPayment(d, a, note.text.trim(), walletId: wid);
                  Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(d.person, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(context);
                  debtDialog(context, d: d);
                },
              ),
              IconButton(
                tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirmDialog(context, 'Hapus catatan ${d.person} beserta riwayat pembayarannya?')) {
                    await s.deleteDebt(d.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ]),
            Text(d.owedToMe ? 'Piutang' : 'Hutang saya', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _kv(context, 'Total', rp(d.amount))),
              Expanded(child: _kv(context, 'Terbayar', rp(d.paid))),
              Expanded(child: _kv(context, 'Sisa', rp(d.remaining))),
            ]),
            if (d.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(d.note)),
            const SizedBox(height: 12),
            if (!d.settled)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: pay,
                icon: const Icon(Icons.add),
                label: Text(d.owedToMe ? 'Catat penerimaan' : 'Catat pembayaran'),
              ),
            const SizedBox(height: 12),
            Text('Riwayat', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (d.payments.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Belum ada pembayaran')),
            for (final p in d.payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconBadge(icon: Icons.payments_outlined, color: color, size: 36),
                title: Text(rp(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${tgl(p.date)}${p.note.isEmpty ? '' : ' · ${p.note}'}'),
                trailing: IconButton(tooltip: 'Hapus pembayaran', icon: const Icon(Icons.close), onPressed: () => s.deletePayment(d, p.id)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: Theme.of(context).textTheme.labelSmall),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);
}

Future<void> splitDialog(BuildContext context) async {
  final s = AppScope.of(context);
  final total = TextEditingController();
  final names = TextEditingController();
  final note = TextEditingController();
  var people = 3;
  String? walletId = s.activeWallets.isNotEmpty ? s.activeWallets.first.id : null;
  final expCats = s.cats.where((c) => c.isExpense).toList();
  String? catId = (fallbackCat(s, true) ?? (expCats.isNotEmpty ? expCats.first : null))?.id;
  var saved = false;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final t = parseAmount(total.text);
        final each = t > 0 ? splitEach(t, people) : 0.0;
        final mine = t - each * (people - 1);
        return AlertDialog(
          title: const Text('Patungan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: total,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahFormatter()],
                onChanged: (_) => set(() {}),
                decoration: fieldDeco(ctx, 'Total tagihan', prefix: currencySymbol),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Text('Jumlah orang (termasuk Anda)')),
                IconButton(tooltip: 'Kurangi orang', icon: const Icon(Icons.remove_circle_outline), onPressed: people > 2 ? () => set(() => people--) : null),
                Text('$people', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(tooltip: 'Tambah orang', icon: const Icon(Icons.add_circle_outline), onPressed: people < 20 ? () => set(() => people++) : null),
              ]),
              TextField(controller: names, decoration: fieldDeco(ctx, 'Nama teman (pisahkan koma)', hint: 'Budi, Sari')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: walletId,
                isExpanded: true,
                decoration: fieldDeco(ctx, 'Dibayar dari dompet'),
                items: [for (final w in s.activeWallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
                onChanged: (v) => set(() => walletId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: catId,
                isExpanded: true,
                decoration: fieldDeco(ctx, 'Kategori bagian Anda'),
                items: [for (final c in expCats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => set(() => catId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: fieldDeco(ctx, 'Catatan', hint: 'mis. Makan malam')),
              if (t > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Bagian Anda ${rp(mine)} · tiap teman ${rp(each)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 6),
              Text(
                'Bagian Anda dicatat sebagai pengeluaran. Bagian teman dicatat sebagai piutang dan tidak dihitung sebagai pengeluaran.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final amount = parseAmount(total.text);
                if (amount <= 0 || walletId == null) return;
                final list = names.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final count = list.length > people - 1 ? list.length : people - 1;
                final others = [for (var i = 0; i < count; i++) i < list.length ? list[i] : 'Teman ${i + 1}'];
                await s.createSplit(total: amount, others: others, walletId: walletId!, categoryId: catId, note: note.text.trim());
                saved = true;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Catat'),
            ),
          ],
        );
      },
    ),
  );
  if (saved && context.mounted) snack(context, 'Patungan dicatat');
}
