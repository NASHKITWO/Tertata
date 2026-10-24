import '../data/models.dart';

/// Hasil tebakan transaksi dari teks notifikasi atau SMS bank/e-wallet.
class NotifGuess {
  const NotifGuess({
    required this.type,
    required this.amount,
    required this.date,
    this.merchant,
    this.walletHint,
    this.toHint,
    this.note = '',
    this.raw = '',
  });
  final TxType type;
  final double amount;
  final DateTime date;
  final String? merchant;
  final String? walletHint; // nama bank/e-wallet pengirim notifikasi
  final String? toHint; // untuk top up: e-wallet tujuan
  final String note;
  final String raw;
}

const _walletNames = <String>[
  'gopay', 'ovo', 'dana', 'shopeepay', 'linkaja', 'bca', 'mandiri', 'bni', 'bri', 'bsi', 'cimb', 'jago', 'seabank', 'permata', 'danamon', 'jenius', 'blu', 'flip',
];

const _incomeWords = <String>[
  'menerima', 'diterima', 'dana masuk', 'uang masuk', 'kredit', 'received', 'refund', 'pengembalian dana', 'cashback', 'gaji', 'salary', 'setoran', 'transfer masuk',
];
const _expenseWords = <String>[
  'pembayaran', 'membayar', 'dibayar', 'bayar', 'transfer ke', 'keluar', 'debit', 'pembelian', 'belanja', 'tarik tunai', 'purchase', 'payment', 'transaksi', 'trf ke', 'kartu kredit',
];

final _amountRe = RegExp(r'(?:\brp\.?|\bidr)\s*([0-9][0-9.,]*)', caseSensitive: false);
final _dateRe = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');

double? _parseIdr(String raw) {
  final s = raw.trim().replaceAll(RegExp(r'[.,]+$'), '');
  if (s.isEmpty) return null;
  if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})?$').hasMatch(s)) {
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  }
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$').hasMatch(s)) {
    return double.tryParse(s.replaceAll(',', ''));
  }
  return double.tryParse(s.replaceAll(',', '.'));
}

String _title(String t) => t
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w.length <= 3 && w == w.toUpperCase() ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Memecah teks tempelan menjadi beberapa notifikasi (dipisah baris kosong).
List<String> splitNotifications(String input) =>
    input.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// Menebak satu transaksi dari satu notifikasi; null bila tidak ada nominal rupiah.
/// Nominal setelah kata "saldo"/"sisa" dan biaya admin diabaikan.
NotifGuess? parseNotification(String input, {DateTime? now}) {
  final text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();

  double? amount;
  for (final m in _amountRe.allMatches(lower)) {
    final before = lower.substring((m.start - 18).clamp(0, lower.length).toInt(), m.start);
    if (RegExp(r'(saldo|sisa|balance|limit|admin|biaya|fee)[^a-z]{0,12}$').hasMatch(before)) continue;
    final v = _parseIdr(m.group(1)!);
    if (v != null && v > 0) {
      amount = v;
      break;
    }
  }
  if (amount == null) return null;

  var inc = 0;
  var exp = 0;
  for (final w in _incomeWords) {
    if (lower.contains(w)) inc++;
  }
  for (final w in _expenseWords) {
    if (lower.contains(w)) exp++;
  }
  final isTopUp = RegExp(r'top[\s-]?up|isi saldo').hasMatch(lower);
  var type = inc > exp ? TxType.income : TxType.expense;

  String? wallet;
  String? firstFound;
  var firstIdx = 1 << 30;
  final found = <String>[];
  for (final w in _walletNames) {
    final m = RegExp('\\b$w\\b').firstMatch(lower);
    if (m != null) {
      found.add(w);
      if (m.start < firstIdx) {
        firstIdx = m.start;
        firstFound = w;
      }
    }
  }
  wallet = firstFound;
  String? toHint;
  if (isTopUp && found.isNotEmpty) {
    type = TxType.transfer;
    const ew = ['gopay', 'ovo', 'dana', 'shopeepay', 'linkaja'];
    final target = found.where(ew.contains).toList();
    if (target.isNotEmpty) {
      toHint = target.first;
      final src = found.where((w) => !ew.contains(w)).toList();
      wallet = src.isNotEmpty ? src.first : null;
    }
  }

  // pihak lawan transaksi
  String? merchant;
  final pattern = type == TxType.income
      ? RegExp(r'\b(?:dari|from)\s+([A-Za-z0-9&\x27.\- ]{2,40}?)(?=\s*(?:[.,;|]|berhasil|sukses|pada|tgl|tanggal|saldo|ref|rp\b|idr\b|\d{1,2}[/-]\d{1,2}|$))', caseSensitive: false)
      : RegExp(r'\b(?:ke|kepada|di|merchant|to|at)\s+([A-Za-z0-9&\x27.\- ]{2,40}?)(?=\s*(?:[.,;|]|berhasil|sukses|pada|tgl|tanggal|saldo|ref|rp\b|idr\b|\d{1,2}[/-]\d{1,2}|$))', caseSensitive: false);
  final mm = pattern.firstMatch(text);
  if (mm != null) {
    final c = mm.group(1)!.trim();
    if (c.isNotEmpty && !RegExp(r'^(rekening|rek|akun|anda|saldo|bank)\b', caseSensitive: false).hasMatch(c)) merchant = c;
  }

  var date = now ?? DateTime.now();
  date = DateTime(date.year, date.month, date.day);
  final dm = _dateRe.firstMatch(lower);
  if (dm != null) {
    final d = int.parse(dm.group(1)!);
    final mo = int.parse(dm.group(2)!);
    var y = int.parse(dm.group(3)!);
    if (y < 100) y += 2000;
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      final cand = DateTime(y, mo, d);
      if (cand.month == mo) date = cand;
    }
  }

  String note;
  if (isTopUp && toHint != null) {
    note = 'Top up ${_title(toHint)}';
  } else if (merchant != null) {
    final m = _title(merchant);
    if (type == TxType.income) {
      note = 'Dari $m';
    } else if (RegExp(r'transfer|trf').hasMatch(lower)) {
      note = 'Transfer ke $m';
    } else {
      note = m;
    }
  } else {
    note = type == TxType.income ? 'Dana masuk' : '';
  }

  return NotifGuess(
    type: type,
    amount: amount,
    date: date,
    merchant: merchant,
    walletHint: wallet,
    toHint: toHint,
    note: note,
    raw: text,
  );
}
