import 'package:flutter/material.dart';
import '../common.dart';
import '../services/smart.dart';
import 'calc_dialog.dart';

/// Form transaksi. Juga dipakai untuk membuat/mengubah aturan transaksi berulang (rule / newRule).
class TxFormScreen extends StatefulWidget {
  const TxFormScreen({super.key, this.tx, this.rule, this.preset, this.newRule = false});
  final Tx? tx;
  final Recurring? rule;
  final TxType? preset;
  final bool newRule;
  @override
  State<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends State<TxFormScreen> {
  TxType type = TxType.expense;
  final amount = TextEditingController();
  final note = TextEditingController();
  String? catId;
  String? walletId;
  String? toId;
  DateTime date = DateTime.now();
  Freq freq = Freq.monthly;
  DateTime? endDate;
  bool repeat = false;

  bool get ruleMode => widget.rule != null || widget.newRule;

  @override
  void initState() {
    super.initState();
    final t = widget.tx;
    final r = widget.rule;
    if (t != null) {
      type = t.type;
      amount.text = angka(t.amount);
      note.text = t.note;
      catId = t.categoryId;
      walletId = t.walletId;
      toId = t.toWalletId;
      date = t.date;
    } else if (r != null) {
      type = r.type;
      amount.text = angka(r.amount);
      note.text = r.note;
      catId = r.categoryId;
      walletId = r.walletId;
      toId = r.toWalletId;
      date = r.nextDate;
      freq = r.freq;
      endDate = r.endDate;
    } else {
      type = widget.preset ?? TxType.expense;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    walletId ??= s.activeWallets.isNotEmpty ? s.activeWallets.first.id : s.wallets.first.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Color get tcolor => switch (type) {
        TxType.income => kIncome,
        TxType.expense => kExpense,
        TxType.transfer => kTransfer,
      };

  Future<void> _saveTemplate() async {
    final s = AppScope.of(context);
    final a = parseAmount(amount.text);
    if (a <= 0 || (type != TxType.transfer && catId == null)) {
      snack(context, 'Isi nominal dan kategori dulu');
      return;
    }
    final list = s.templates;
    list.insert(0, {'type': type.name, 'amount': a, 'cat': catId, 'wallet': walletId, 'to': toId, 'note': note.text.trim()});
    await s.saveTemplates(list.take(12).toList());
    if (mounted) snack(context, 'Disimpan sebagai favorit');
  }

  void _applyTemplate(Map<String, dynamic> t) {
    final s = AppScope.of(context);
    setState(() {
      type = TxType.values.byName(t['type'] as String);
      amount.text = angka((t['amount'] as num).toDouble());
      catId = s.cat(t['cat'] as String?)?.id;
      final w = t['wallet'] as String?;
      if (w != null && s.wallet(w) != null) walletId = w;
      final to = t['to'] as String?;
      toId = (to != null && s.wallet(to) != null) ? to : null;
      note.text = (t['note'] as String?) ?? '';
    });
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final a = parseAmount(amount.text);
    String? err;
    if (a <= 0) {
      err = 'Masukkan nominal';
    } else if (type != TxType.transfer && catId == null) {
      err = 'Pilih kategori';
    } else if (type == TxType.transfer && (toId == null || toId == walletId)) {
      err = 'Pilih dompet tujuan yang berbeda';
    }
    if (err != null) {
      snack(context, err);
      return;
    }
    final isT = type == TxType.transfer;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final day = dayOnly(date);

    if (ruleMode) {
      await s.saveRecurring(Recurring(
        id: widget.rule?.id ?? s.uid(),
        type: type,
        amount: a,
        walletId: walletId!,
        toWalletId: isT ? toId : null,
        categoryId: isT ? null : catId,
        note: note.text.trim(),
        freq: freq,
        nextDate: day,
        endDate: endDate,
        anchorDay: day.day,
        active: widget.rule?.active ?? true,
      ));
      await s.processRecurring();
      nav.pop();
      return;
    }

    final now = DateTime.now();
    final when = dayOnly(date) == dayOnly(now) ? now : DateTime(date.year, date.month, date.day, 12);
    await s.saveTx(Tx(
      id: widget.tx?.id ?? s.uid(),
      type: type,
      amount: a,
      walletId: walletId!,
      toWalletId: isT ? toId : null,
      categoryId: isT ? null : catId,
      date: widget.tx != null ? date : when,
      note: note.text.trim(),
      recurringId: widget.tx?.recurringId,
      externalId: widget.tx?.externalId,
      created: widget.tx?.created,
    ));
    if (repeat && widget.tx == null) {
      await s.saveRecurring(Recurring(
        id: s.uid(),
        type: type,
        amount: a,
        walletId: walletId!,
        toWalletId: isT ? toId : null,
        categoryId: isT ? null : catId,
        note: note.text.trim(),
        freq: freq,
        nextDate: nextOccurrence(day, freq, day.day),
        endDate: endDate,
        anchorDay: day.day,
      ));
      await s.processRecurring();
    }
    // Peringatan anggaran
    if (type == TxType.expense && catId != null) {
      for (final b in s.budgets.where((b) => b.categoryId == catId)) {
        final spent = s.spentCat(b.categoryId, date);
        final limit = s.budgetLimit(b, date);
        if (spent >= limit) {
          messenger.showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Anggaran ${s.cat(catId)?.name ?? ''} terlampaui (${rp(spent)} / ${rp(limit)})'),
          ));
        } else if (spent >= limit * .8) {
          messenger.showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Anggaran ${s.cat(catId)?.name ?? ''} sudah ${(spent / limit * 100).round()}%'),
          ));
        }
      }
    }
    nav.pop();
  }

  Widget _typePill(String label, TxType t) {
    final sel = type == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          type = t;
          catId = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.white.soft(.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? tcolor : Colors.white)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cats = s.cats.where((c) => c.isExpense == (type == TxType.expense)).toList();
    final itemW = (MediaQuery.of(context).size.width - 32 - 32 - 24) / 4;
    final editing = widget.tx != null || widget.rule != null;
    final wallets = s.wallets.where((w) => !w.archived || w.id == walletId || w.id == toId).toList();
    final sug = (type != TxType.transfer && catId == null) ? suggestCategory(s, note.text, type) : null;
    final templates = (widget.tx == null && !ruleMode) ? s.templates : <Map<String, dynamic>>[];

    return Scaffold(
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          decoration: BoxDecoration(color: tcolor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Row(children: [
                const BackButton(color: Colors.white),
                Expanded(
                  child: Text(
                    ruleMode
                        ? (widget.rule == null ? 'Transaksi Berulang Baru' : 'Ubah Transaksi Berulang')
                        : (widget.tx == null ? 'Catat Transaksi' : 'Ubah Transaksi'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!ruleMode && widget.tx == null)
                  IconButton(
                    tooltip: 'Simpan sebagai favorit',
                    icon: const Icon(Icons.star_border_rounded, color: Colors.white),
                    onPressed: _saveTemplate,
                  ),
                if (widget.tx != null)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    tooltip: 'Duplikat',
                    onPressed: () async {
                      final t = widget.tx!;
                      final nav = Navigator.of(context);
                      await s.saveTx(Tx(
                        id: s.uid(),
                        type: t.type,
                        amount: t.amount,
                        walletId: t.walletId,
                        toWalletId: t.toWalletId,
                        categoryId: t.categoryId,
                        date: DateTime.now(),
                        note: t.note,
                      ));
                      nav.pop();
                    },
                  ),
                if (editing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () async {
                      if (!await confirmDialog(context, 'Hapus data ini?')) return;
                      if (widget.tx != null) await s.deleteTx(widget.tx!.id);
                      if (widget.rule != null) await s.deleteRecurring(widget.rule!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  _typePill('Keluar', TxType.expense),
                  _typePill('Masuk', TxType.income),
                  _typePill('Pindah dana', TxType.transfer),
                ]),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahFormatter()],
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white.soft(.45)),
                  prefixText: currencySymbol,
                  prefixStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final r = await showCalcDialog(context, initial: amount.text);
                  if (r != null) setState(() => amount.text = angka(r));
                },
                icon: const Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
                label: const Text('Kalkulator', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (templates.isNotEmpty) ...[
                SizedBox(
                  height: 42,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (var i = 0; i < templates.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: () async {
                            if (await confirmDialog(context, 'Hapus favorit ini?')) {
                              final l = s.templates;
                              if (i < l.length) l.removeAt(i);
                              await s.saveTemplates(l);
                            }
                          },
                          child: ActionChip(
                            avatar: const Icon(Icons.star_rounded, size: 16, color: kWarn),
                            label: Text(
                              '${((templates[i]['note'] as String?) ?? '').isNotEmpty ? templates[i]['note'] : (s.cat(templates[i]['cat'] as String?)?.name ?? 'Favorit')} · ${rpShort(templates[i]['amount'] as num)}',
                            ),
                            onPressed: () => _applyTemplate(templates[i]),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  DropdownButtonFormField<String>(
                    initialValue: walletId,
                    decoration: fieldDeco(context, type == TxType.transfer ? 'Dari dompet' : 'Dompet', icon: Icons.account_balance_wallet_outlined),
                    items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
                    onChanged: (v) => setState(() {
                      walletId = v;
                      if (toId == v) toId = null;
                    }),
                  ),
                  if (type == TxType.transfer) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: toId,
                      decoration: fieldDeco(context, 'Ke dompet', icon: Icons.south_east),
                      items: [for (final w in wallets.where((w) => w.id != walletId)) DropdownMenuItem(value: w.id, child: Text(w.name))],
                      onChanged: (v) => setState(() => toId = v),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hanya mencatat perpindahan saldo antar dompet. Tidak ada uang yang dipindahkan sungguhan.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ]),
              ),
              if (type != TxType.transfer)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Kategori', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (sug != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ActionChip(
                          avatar: const AiSparkle(size: 16),
                          label: Text('Saran: ${sug.name}'),
                          onPressed: () => setState(() => catId = sug.id),
                        ),
                      ),
                    Wrap(spacing: 8, runSpacing: 10, children: [
                      for (final c in cats)
                        GestureDetector(
                          onTap: () => setState(() => catId = c.id),
                          child: Container(
                            width: itemW,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: catId == c.id ? Color(c.color).soft(.12) : Colors.transparent,
                              border: Border.all(color: catId == c.id ? Color(c.color) : Colors.transparent, width: 1.5),
                            ),
                            child: Column(children: [
                              IconBadge(icon: kIcons[c.icon], color: Color(c.color), size: 40),
                              const SizedBox(height: 6),
                              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            ]),
                          ),
                        ),
                    ]),
                  ]),
                ),
              AppCard(
                child: Column(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const IconBadge(icon: Icons.calendar_today, color: kTransfer, size: 38),
                    title: Text(ruleMode ? 'Mulai / berikutnya' : 'Tanggal'),
                    subtitle: Text(tgl(date)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => date = d);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: note, onChanged: (_) => setState(() {}), decoration: fieldDeco(context, 'Catatan (opsional)', icon: Icons.notes)),
                ]),
              ),
              if (ruleMode || widget.tx == null)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!ruleMode)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ulangi transaksi ini'),
                        subtitle: const Text('Dicatat otomatis sesuai jadwal'),
                        value: repeat,
                        onChanged: (v) => setState(() => repeat = v),
                      ),
                    if (ruleMode || repeat) ...[
                      Wrap(spacing: 8, children: [
                        for (final f in Freq.values)
                          ChoiceChip(label: Text(f.label), selected: freq == f, onSelected: (_) => setState(() => freq = f)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event_busy),
                            label: Text(endDate == null ? 'Tanpa tanggal berakhir' : 'Berakhir ${tgl(endDate!)}'),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? date.add(const Duration(days: 365)),
                                firstDate: date,
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => endDate = d);
                            },
                          ),
                        ),
                        if (endDate != null) IconButton(tooltip: 'Hapus tanggal akhir', icon: const Icon(Icons.clear), onPressed: () => setState(() => endDate = null)),
                      ]),
                    ],
                  ]),
                ),
              const SizedBox(height: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: tcolor, minimumSize: const Size.fromHeight(54)),
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ]),
    );
  }
}
