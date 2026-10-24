import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:catatan_uang/services/csv_import.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  test('parseMoney: format Indonesia dan internasional', () {
    expect(parseMoney('1.250.000'), 1250000);
    expect(parseMoney('1.250.000,50'), 1250000.5);
    expect(parseMoney('1,250,000.50'), 1250000.5);
    expect(parseMoney('Rp 50.000'), 50000);
    expect(parseMoney('-50.000'), -50000);
    expect(parseMoney('(25.000)'), -25000);
    expect(parseMoney('50.000 DB'), -50000);
    expect(parseMoney('50.000 CR'), 50000);
    expect(parseMoney(''), isNull);
    expect(parseMoney('abc'), isNull);
  });

  test('parseCsv: kutip, titik koma, BOM, CRLF', () {
    final r = parseCsv('\uFEFFTanggal;Keterangan;Jumlah\r\n01/10/2026;"Makan; siang";-35.000\r\n');
    expect(r.length, 2);
    expect(r[0][0], 'Tanggal');
    expect(r[1][1], 'Makan; siang');
  });

  test('guessCsv + parseRows: kolom debit & kredit dengan baris pembuka', () {
    final rows = parseCsv('Rekening 123\nTanggal,Keterangan,Debit,Kredit\n17/10/2026,Kopi,25.000,\n18/10/2026,Gaji,,8.000.000\n');
    final g = guessCsv(rows);
    expect(g.header, 1);
    expect(g.twoCols, true);
    expect(g.dateFmt, 'dd/MM/yyyy');
    final res = parseRows(rows,
        header: g.header, cDate: g.date, cDesc: g.desc, cAmount: g.amount, cDebit: g.debit, cCredit: g.credit, twoCols: g.twoCols, flip: false, dateFmt: g.dateFmt);
    expect(res.rows.length, 2);
    expect(res.rows[0].isExpense, true);
    expect(res.rows[0].amount, 25000);
    expect(res.rows[1].isExpense, false);
    expect(res.rows[1].amount, 8000000);
  });

  test('parseRows: transaksi identik di hari sama tetap unik (bukan duplikat)', () {
    final rows = parseCsv('Tanggal,Keterangan,Jumlah\n17/10/2026,Kopi,-25000\n17/10/2026,Kopi,-25000\n');
    final g = guessCsv(rows);
    final res = parseRows(rows, header: g.header, cDate: g.date, cDesc: g.desc, cAmount: g.amount, twoCols: false, flip: false, dateFmt: g.dateFmt);
    expect(res.rows.length, 2);
    expect(res.rows[0].key == res.rows[1].key, false);
  });
}
