import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../common.dart';
import '../services/csv_import.dart';
import '../services/smart.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<List<String>> rows = [];
  String? fileName;
  int header = 0;
  int? cDate;
  int? cDesc;
  int? cAmount;
  int? cDebit;
  int? cCredit;
  bool twoCols = false;
  bool flip = false;
  String? walletId;
  String? dateFmt;
  bool busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    walletId ??= s.activeWallets.isNotEmpty ? s.activeWallets.first.id : null;
  }

  Future<void> _pick() async {
    final s = AppScope.of(context);
    s.suppressLock = true;
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (r == null || r.files.single.path == null) {
      s.suppressLock = false;
      return;
    }
    try {
      final bytes = await File(r.files.single.path!).readAsBytes();
      final parsed = parseCsv(utf8.decode(bytes, allowMalformed: true));
      if (parsed.length < 2) {
        if (mounted) snack(context, 'File kosong atau formatnya tidak dikenali');
        return;
      }
      final g = guessCsv(parsed);
      if (!mounted) return;
      setState(() {
        rows = parsed;
        fileName = r.files.single.name;
        header = g.header;
        cDate = g.date;
        cDesc = g.desc;
        cAmount = g.amount;
        cDebit = g.debit;
        cCredit = g.credit;
        twoCols = g.twoCols;
        dateFmt = g.dateFmt;
        flip = false;
      });
    } catch (_) {
      if (mounted) snack(context, 'Gagal membaca file');
    }
  }

  ImportResult _parse() => parseRows(
        rows,
        header: header,
        cDate: cDate,
        cDesc: cDesc,
        cAmount: cAmount,
        cDebit: cDebit,
        cCredit: cCredit,
        twoCols: twoCols,
        flip: flip,
        dateFmt: dateFmt,
      );

  String _ext(ImportRow r) => sha256.convert(utf8.encode('$walletId|${r.key}')).toString().substring(0, 24);

  Future<void> _import(ImportResult res, Set<String> existing) async {
    final s = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => busy = true);
    final idx = CategoryIndex(s);
    final created = <Tx>[];
    for (final r in res.rows) {
      final ext = _ext(r);
      if (existing.contains(ext)) continue;
      final type = r.isExpense ? TxType.expense : TxType.income;
      final c = idx.suggest(r.desc, type) ?? fallbackCat(s, r.isExpense);
      created.add(Tx(
        id: s.uid(),
        type: type,
        amount: r.amount,
        walletId: walletId!,
        categoryId: c?.id,
        date: DateTime(r.date.year, r.date.month, r.date.day, 12),
        note: r.desc.length > 120 ? r.desc.substring(0, 120) : r.desc,
        externalId: ext,
      ));
    }
    await s.importTxs(created);
    nav.pop();
    if (created.isEmpty) {
      messenger.showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Tidak ada transaksi baru untuk diimpor')));
    } else {
      final ids = created.map((t) => t.id).toSet();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${created.length} transaksi diimpor'),
        action: SnackBarAction(label: 'URUNGKAN', onPressed: () => s.deleteTxs(ids)),
      ));
    }
  }

  List<DropdownMenuItem<int?>> _colItems(List<String> head) => [
        const DropdownMenuItem<int?>(value: null, child: Text('(tidak ada)')),
        for (var i = 0; i < head.length; i++)
          DropdownMenuItem<int?>(
            value: i,
            child: Text('${i + 1}. ${head[i].trim().isEmpty ? '(kosong)' : head[i].trim()}', overflow: TextOverflow.ellipsis),
          ),
      ];

  Widget _col(String label, int? value, ValueChanged<int?> onChanged, List<String> head) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<int?>(
          value: value != null && value < head.length ? value : null,
          isExpanded: true,
          decoration: fieldDeco(context, label),
          items: _colItems(head),
          onChanged: onChanged,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;

    if (rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Impor Mutasi')),
        body: EmptyState(
          icon: Icons.upload_file_outlined,
          title: 'Impor mutasi dari file CSV',
          subtitle:
              'Unduh mutasi rekening dari internet banking atau e-wallet dalam format CSV, lalu pilih filenya di sini. Kolom dikenali otomatis dan transaksi yang sudah pernah diimpor tidak akan terduplikasi.',
          actionLabel: 'Pilih file CSV',
          onAction: _pick,
        ),
      );
    }

    final head = header < rows.length ? rows[header] : <String>[];
    final res = _parse();
    final existing = {for (final t in s.txs) if (t.externalId != null) t.externalId!};
    final fresh = walletId == null ? <ImportRow>[] : res.rows.where((r) => !existing.contains(_ext(r))).toList();
    final dups = res.rows.length - fresh.length;
    final income = fresh.where((r) => !r.isExpense).fold(0.0, (a, r) => a + r.amount);
    final expense = fresh.where((r) => r.isExpense).fold(0.0, (a, r) => a + r.amount);
    final ready = walletId != null && cDate != null && (twoCols ? (cDebit != null || cCredit != null) : cAmount != null) && fresh.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Impor Mutasi')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(fileName ?? 'File', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: _pick, child: const Text('Ganti')),
          ]),
        ),
        const SectionHeader('Pengaturan'),
        AppCard(
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: walletId,
              decoration: fieldDeco(context, 'Masukkan ke dompet', icon: Icons.account_balance_wallet_outlined),
              items: [for (final w in s.activeWallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
              onChanged: (v) => setState(() => walletId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: header < rows.length && header < 10 ? header : 0,
              decoration: fieldDeco(context, 'Baris judul kolom'),
              items: [for (var i = 0; i < (rows.length < 10 ? rows.length : 10); i++) DropdownMenuItem(value: i, child: Text('Baris ${i + 1}'))],
              onChanged: (v) => setState(() => header = v ?? 0),
            ),
            const SizedBox(height: 12),
            _col('Kolom tanggal', cDate, (v) => setState(() => cDate = v), head),
            _col('Kolom keterangan', cDesc, (v) => setState(() => cDesc = v), head),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Satu kolom jumlah')),
                  ButtonSegment(value: true, label: Text('Debit & kredit')),
                ],
                selected: {twoCols},
                onSelectionChanged: (v) => setState(() => twoCols = v.first),
              ),
            ),
            const SizedBox(height: 12),
            if (!twoCols) ...[
              _col('Kolom jumlah', cAmount, (v) => setState(() => cAmount = v), head),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Balik tanda'),
                subtitle: const Text('Aktifkan jika nilai positif di file adalah pengeluaran'),
                value: flip,
                onChanged: (v) => setState(() => flip = v),
              ),
            ] else ...[
              _col('Kolom debit (uang keluar)', cDebit, (v) => setState(() => cDebit = v), head),
              _col('Kolom kredit (uang masuk)', cCredit, (v) => setState(() => cCredit = v), head),
            ],
            DropdownButtonFormField<String?>(
              value: dateFmt,
              decoration: fieldDeco(context, 'Format tanggal'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Deteksi otomatis')),
                for (final f in kDateFormats)
                  DropdownMenuItem<String?>(value: f, child: Text('$f  (${DateFormat(f, 'en_US').format(DateTime(2026, 10, 17))})')),
              ],
              onChanged: (v) => setState(() => dateFmt = v),
            ),
          ]),
        ),
        const SectionHeader('Pratinjau'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _stat(context, 'Baru', '${fresh.length}', cs.primary)),
              Expanded(child: _stat(context, 'Sudah ada', '$dups', cs.onSurfaceVariant)),
              Expanded(child: _stat(context, 'Dilewati', '${res.invalid}', res.invalid > 0 ? kWarn : cs.onSurfaceVariant)),
            ]),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('+ ${rp(income)}', style: const TextStyle(color: kIncome, fontWeight: FontWeight.w700)),
              Text('- ${rp(expense)}', style: const TextStyle(color: kExpense, fontWeight: FontWeight.w700)),
            ]),
            if (fresh.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in fresh.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 58, child: Text(DateFormat('d MMM', 'id_ID').format(r.date), style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.desc.isEmpty ? '(tanpa keterangan)' : r.desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          suggestCategory(s, r.desc, r.isExpense ? TxType.expense : TxType.income)?.name ?? 'Lainnya',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ]),
                    ),
                    Text('${r.isExpense ? '-' : '+'}${rp(r.amount)}', style: TextStyle(fontWeight: FontWeight.w700, color: r.isExpense ? kExpense : kIncome)),
                  ]),
                ),
            ],
            if (dateFmt == null && cDate != null && res.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Format tanggal tidak dikenali. Pilih format secara manual.', style: TextStyle(color: cs.error)),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: (!ready || busy) ? null : () => _import(res, existing),
          icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_done),
          label: Text('Impor ${fresh.length} transaksi'),
        ),
        const SizedBox(height: 12),
        Text(
          'Kategori ditebak dari riwayat dan kata kunci. Yang belum cocok masuk "Lainnya"; rapikan lewat tab Asisten > "Rapikan kategori transaksi".',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) => Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]);
}
