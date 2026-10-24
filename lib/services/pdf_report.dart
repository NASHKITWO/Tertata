import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../common.dart';

String _safe(String t) => String.fromCharCodes(t.runes.map((r) => r <= 255 ? r : 63));

Future<Uint8List> buildReportPdf(AppState s, DateTime from, DateTime to, String label) async {
  final doc = pw.Document();
  final inc = s.sumBetween(from, to, TxType.income);
  final exp = s.sumBetween(from, to, TxType.expense);
  final cats = s.byCategory(from, to, TxType.expense).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final txs = s.between(from, to).reversed.toList();
  const teal = PdfColor.fromInt(0xFF0F766E);

  pw.Widget cell(String t, {bool bold = false, pw.Alignment align = pw.Alignment.centerLeft}) => pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(_safe(t), style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  const border = pw.TableBorder(horizontalInside: pw.BorderSide(width: .3, color: PdfColors.grey500));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Halaman ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ),
    build: (ctx) => [
      pw.Text('Laporan Keuangan', style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: teal)),
      pw.SizedBox(height: 2),
      pw.Text(_safe(label), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          pw.Column(children: [pw.Text('Pemasukan', style: const pw.TextStyle(fontSize: 9)), pw.Text(_safe(rp(inc)), style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
          pw.Column(children: [pw.Text('Pengeluaran', style: const pw.TextStyle(fontSize: 9)), pw.Text(_safe(rp(exp)), style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
          pw.Column(children: [pw.Text('Selisih', style: const pw.TextStyle(fontSize: 9)), pw.Text(_safe(rp(inc - exp)), style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
        ]),
      ),
      pw.SizedBox(height: 16),
      if (cats.isNotEmpty) ...[
        pw.Text('Pengeluaran per kategori', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: border,
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(50)},
          children: [
            for (final e in cats)
              pw.TableRow(children: [
                cell(s.cat(e.key)?.name ?? 'Tanpa kategori'),
                cell(rp(e.value), align: pw.Alignment.centerRight),
                cell('${exp == 0 ? 0 : (e.value / exp * 100).toStringAsFixed(1)}%', align: pw.Alignment.centerRight),
              ]),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
      pw.Text('Daftar transaksi (${txs.length})', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Table(
        border: border,
        columnWidths: {
          0: const pw.FixedColumnWidth(58),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(3),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              cell('Tanggal', bold: true),
              cell('Kategori', bold: true),
              cell('Dompet', bold: true),
              cell('Catatan', bold: true),
              cell('Jumlah', bold: true, align: pw.Alignment.centerRight),
            ],
          ),
          for (final t in txs)
            pw.TableRow(children: [
              cell(tgl(t.date)),
              cell(t.type == TxType.transfer ? 'Pindah dana' : (s.cat(t.categoryId)?.name ?? '-')),
              cell(s.wallet(t.walletId)?.name ?? '-'),
              cell(t.note),
              cell('${t.type == TxType.income ? '+' : (t.type == TxType.expense ? '-' : '')}${rp(t.amount)}', align: pw.Alignment.centerRight),
            ]),
        ],
      ),
    ],
  ));
  return doc.save();
}
