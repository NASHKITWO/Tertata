import 'package:intl/intl.dart';

String currencySymbol = 'Rp ';
NumberFormat? _f;
String? _fSym;

String rp(num v) {
  if (_f == null || _fSym != currencySymbol) {
    _f = NumberFormat.currency(locale: 'id_ID', symbol: currencySymbol, decimalDigits: 0);
    _fSym = currencySymbol;
  }
  return _f!.format(v);
}

String rpShort(num v) => NumberFormat.compact(locale: 'id_ID').format(v);
String angka(num v) => NumberFormat('#,###', 'id_ID').format(v.toInt());
String tgl(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);
String tglHari(DateTime d) => DateFormat('EEEE, d MMM', 'id_ID').format(d);
String bulan(DateTime d) => DateFormat('MMMM yyyy', 'id_ID').format(d);
String bulanSingkat(DateTime d) => DateFormat('MMM', 'id_ID').format(d);
String hariSingkat(DateTime d) => DateFormat('E', 'id_ID').format(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String relDay(DateTime d) {
  final today = dayOnly(DateTime.now());
  final diff = dayOnly(d).difference(today).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  if (diff == -1) return 'Kemarin';
  return tglHari(d);
}
