import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common.dart';
import '../services/native_bridge.dart';
import '../services/notif_parser.dart';
import '../services/smart.dart';

class _Row {
  _Row(this.g, this.type, this.selected, this.duplicate, this.blocked);
  final NotifGuess g;
  TxType type;
  bool selected;
  final bool duplicate;
  final String? blocked; // alasan tidak bisa disimpan
}

/// Tempel teks notifikasi/SMS bank atau e-wallet; aplikasi menebak transaksinya (diproses di perangkat, tanpa AI).
class PasteNotifPage extends StatefulWidget {
  const PasteNotifPage({super.key, this.fromInbox = false});

  /// true: isi otomatis dari kotak masuk notifikasi yang ditangkap Android.
  final bool fromInbox;
  @override
  State<PasteNotifPage> createState() => _PasteNotifPageState();
}

class _PasteNotifPageState extends State<PasteNotifPage> {
  final ctrl = TextEditingController();
  List<_Row> rows = [];
  int skipped = 0;
  bool analyzed = false;

  @override
  void initState() {
    super.initState();
    if (widget.fromInbox) WidgetsBinding.instance.addPostFrameCallback((_) => _loadInbox());
  }

  Future<void> _loadInbox() async {
    final items = await NativeBridge.pending();
    if (!mounted) return;
    ctrl.text = items.map((e) => e.parseText).join('\n\n');
    _analyze();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    if (t.trim().isEmpty) {
      if (mounted) snack(context, 'Clipboard kosong. Salin dulu teks notifikasi atau SMS.');
      return;
    }
    ctrl.text = t;
    _analyze();
  }

  void _analyze() {
    final s = AppScope.of(context);
    final out = <_Row>[];
    var skip = 0;
    for (final block in splitNotifications(ctrl.text)) {
      final g = parseNotification(block);
      if (g == null) {
        skip++;
        continue;
      }
      String? blocked;
      if (g.type == TxType.transfer) {
        final to = findWallet(s, g.toHint);
        final from = findWallet(s, g.walletHint);
        if (to == null || from == null || to.id == from.id) blocked = 'Dompet asal/tujuan belum cocok. Catat lewat "Pindah".';
      }
      final dup = s.txs.any((t) =>
          t.amount == g.amount && t.type == g.type && dayOnly(t.date) == dayOnly(g.date) && !t.neutral);
      out.add(_Row(g, g.type, blocked == null && !dup, dup, blocked));
    }
    setState(() {
      rows = out;
      skipped = skip;
      analyzed = true;
    });
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final items = <TxDraft>[];
    for (final r in rows.where((r) => r.selected && r.blocked == null)) {
      final isT = r.type == TxType.transfer;
      final cat = isT ? null : suggestCategory(s, r.g.note.isEmpty ? r.g.raw : r.g.note, r.type);
      items.add(TxDraft(
        type: r.type,
        amount: r.g.amount,
        category: cat?.name,
        wallet: findWallet(s, r.g.walletHint)?.name,
        toWallet: isT ? findWallet(s, r.g.toHint)?.name : null,
        date: r.g.date,
        note: r.g.note,
      ));
    }
    if (items.isEmpty) {
      snack(context, 'Pilih minimal satu transaksi');
      return;
    }
    final n = await applyTxDrafts(s, TxDraftSet(items));
    if (widget.fromInbox) await NativeBridge.clearPending();
    if (!mounted) return;
    snack(context, '$n transaksi disimpan');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final count = rows.where((r) => r.selected && r.blocked == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fromInbox ? 'Kotak Masuk Notifikasi' : 'Tempel Notifikasi'),
        actions: [
          if (widget.fromInbox)
            IconButton(
              tooltip: 'Kosongkan kotak masuk',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final nav = Navigator.of(context);
                if (await confirmDialog(context, 'Kosongkan semua notifikasi di kotak masuk tanpa mencatat?', ok: 'Kosongkan')) {
                  await NativeBridge.clearPending();
                  nav.pop();
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(onPressed: count == 0 ? null : _save, child: Text('Simpan $count transaksi')),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Salin teks notifikasi atau SMS dari bank/e-wallet, lalu tempel di sini. Beberapa notifikasi bisa dipisah dengan baris kosong. Semuanya dibaca di perangkat Anda, tanpa AI dan tanpa internet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            minLines: 4,
            maxLines: 9,
            decoration: fieldDeco(context, 'Teks notifikasi / SMS', hint: 'Contoh: GoPay: Pembayaran Rp25.000 ke Kopi Kenangan berhasil'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste, size: 18), label: const Text('Tempel')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(onPressed: _analyze, icon: const Icon(Icons.auto_fix_high, size: 18), label: const Text('Baca')),
            ),
          ]),
          const SizedBox(height: 12),
          if (analyzed && rows.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.search_off,
                title: 'Tidak ada nominal rupiah',
                subtitle: 'Pastikan teks memuat nominal seperti "Rp 25.000".',
              ),
            ),
          if (skipped > 0 && rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('$skipped teks dilewati karena tidak memuat nominal.', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final r in rows) _card(context, s, cs, r),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, AppState s, ColorScheme cs, _Row r) {
    final isT = r.type == TxType.transfer;
    final color = switch (r.type) {
      TxType.income => kIncome,
      TxType.expense => kExpense,
      TxType.transfer => kTransfer,
    };
    final sign = switch (r.type) {
      TxType.income => '+',
      TxType.expense => '-',
      TxType.transfer => '',
    };
    final wallet = findWallet(s, r.g.walletHint) ?? (s.activeWallets.isNotEmpty ? s.activeWallets.first : null);
    final cat = isT ? null : suggestCategory(s, r.g.note.isEmpty ? r.g.raw : r.g.note, r.type);
    final detail = [
      if (isT) '${wallet?.name ?? '?'} → ${findWallet(s, r.g.toHint)?.name ?? '?'}' else wallet?.name ?? '?',
      if (cat != null) cat.name,
      tgl(r.g.date),
    ].join(' · ');
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(
            value: r.selected && r.blocked == null,
            onChanged: r.blocked != null ? null : (v) => setState(() => r.selected = v ?? false),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.g.note.isEmpty ? 'Tanpa catatan' : r.g.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Text('$sign${rp(r.g.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        if (!isT)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Keluar'), selected: r.type == TxType.expense, onSelected: (_) => setState(() => r.type = TxType.expense)),
              ChoiceChip(label: const Text('Masuk'), selected: r.type == TxType.income, onSelected: (_) => setState(() => r.type = TxType.income)),
            ]),
          ),
        if (r.duplicate)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 8),
            child: SoftChip(text: 'Mirip transaksi yang sudah ada', color: kWarn, icon: Icons.copy_all_outlined),
          ),
        if (r.blocked != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(r.blocked!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
      ]),
    );
  }
}
