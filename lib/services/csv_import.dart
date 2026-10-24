import 'dart:math';
import 'package:intl/intl.dart';

const kDateFormats = <String>[
  'dd/MM/yyyy',
  'dd-MM-yyyy',
  'yyyy-MM-dd',
  'yyyy/MM/dd',
  'd/M/yyyy',
  'dd/MM/yy',
  'dd MMM yyyy',
  'MM/dd/yyyy',
];

// ======================= CSV =======================

List<List<String>> parseCsv(String input) {
  final text = input.replaceFirst('\uFEFF', '');
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).take(10).toList();
  var delim = ',';
  var best = -1;
  for (final d in [',', ';', '\t', '|']) {
    var total = 0;
    for (final l in lines) {
      total += d.allMatches(l).length;
    }
    if (total > best) {
      best = total;
      delim = d;
    }
  }

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQ = false;

  void endRow() {
    row.add(field.toString());
    field.clear();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == delim) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

// ======================= NOMINAL =======================

/// Mengurai nominal format Indonesia/internasional. Negatif jika ada tanda minus, kurung, atau akhiran DB/DR/D.
double? parseMoney(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  var neg = false;
  if (RegExp(r'\b(DB|DR|D)$').hasMatch(s.toUpperCase())) neg = true;
  if (s.startsWith('(') && s.endsWith(')')) neg = true;
  if (s.contains('-')) neg = true;
  s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (s.isEmpty) return null;

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  var intPart = s;
  var frac = '';
  if (lastDot >= 0 && lastComma >= 0) {
    final idx = max(lastDot, lastComma);
    intPart = s.substring(0, idx);
    frac = s.substring(idx + 1);
  } else if (lastDot >= 0 || lastComma >= 0) {
    final idx = max(lastDot, lastComma);
    final after = s.length - idx - 1;
    final seps = '.'.allMatches(s).length + ','.allMatches(s).length;
    if (seps == 1 && after > 0 && after <= 2) {
      intPart = s.substring(0, idx);
      frac = s.substring(idx + 1);
    }
  }
  intPart = intPart.replaceAll(RegExp(r'[.,]'), '');
  final v = double.tryParse(frac.isEmpty ? intPart : '$intPart.$frac');
  if (v == null) return null;
  return neg ? -v : v;
}

// ======================= TANGGAL =======================

DateTime? parseDate(String raw, String? fmt) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final formats = fmt == null ? kDateFormats : [fmt];
  for (final f in formats) {
    final t = f.contains(' ') ? text : text.split(RegExp(r'[ T]')).first;
    for (final loc in f.contains('MMM') ? ['id_ID', 'en_US'] : ['id_ID']) {
      try {
        final d = DateFormat(f, loc).parseStrict(t);
        return DateTime(d.year, d.month, d.day);
      } catch (_) {}
    }
  }
  return null;
}

String? detectDateFormat(List<String> samples) {
  final s = samples.where((x) => x.trim().isNotEmpty).take(25).toList();
  if (s.isEmpty) return null;
  for (final f in kDateFormats) {
    if (s.every((x) => parseDate(x, f) != null)) return f;
  }
  return null;
}

// ======================= DETEKSI KOLOM =======================

const _dateKeys = ['tanggal', 'tgl', 'date'];
const _descKeys = ['keterangan', 'deskripsi', 'description', 'uraian', 'remark', 'berita', 'transaksi', 'detail'];
const _amountKeys = ['jumlah', 'amount', 'nominal', 'mutasi', 'nilai'];
const _debitKeys = ['debit', 'db', 'keluar', 'pengeluaran'];
const _creditKeys = ['kredit', 'credit', 'cr', 'masuk', 'pemasukan'];

int? _find(List<String> head, List<String> keys, Set<int> exclude) {
  for (var i = 0; i < head.length; i++) {
    if (exclude.contains(i)) continue;
    final h = head[i].toLowerCase().trim();
    for (final k in keys) {
      if (k.length <= 2 ? h == k : h.contains(k)) return i;
    }
  }
  return null;
}

bool _hasAny(List<String> cells, List<String> keys) => _find(cells, keys, {}) != null;

int guessHeaderRow(List<List<String>> rows) {
  for (var i = 0; i < min(rows.length, 15); i++) {
    final cells = rows[i];
    if (_hasAny(cells, _dateKeys) &&
        (_hasAny(cells, _amountKeys) || _hasAny(cells, _debitKeys) || _hasAny(cells, _creditKeys))) {
      return i;
    }
  }
  return 0;
}

class CsvGuess {
  CsvGuess({required this.header, this.date, this.desc, this.amount, this.debit, this.credit, required this.twoCols, this.dateFmt});
  final int header;
  final int? date;
  final int? desc;
  final int? amount;
  final int? debit;
  final int? credit;
  final bool twoCols;
  final String? dateFmt;
}

CsvGuess guessCsv(List<List<String>> rows) {
  final h = guessHeaderRow(rows);
  final head = h < rows.length ? rows[h] : <String>[];
  final used = <int>{};
  final date = _find(head, _dateKeys, used);
  if (date != null) used.add(date);
  final desc = _find(head, _descKeys, used);
  if (desc != null) used.add(desc);
  final amount = _find(head, _amountKeys, used);
  if (amount != null) used.add(amount);
  final debit = _find(head, _debitKeys, used);
  if (debit != null) used.add(debit);
  final credit = _find(head, _creditKeys, used);
  final two = debit != null && credit != null && amount == null;

  String? fmt;
  if (date != null) {
    final samples = <String>[
      for (var i = h + 1; i < rows.length; i++)
        if (date < rows[i].length) rows[i][date],
    ];
    fmt = detectDateFormat(samples);
  }
  return CsvGuess(header: h, date: date, desc: desc, amount: amount, debit: debit, credit: credit, twoCols: two, dateFmt: fmt);
}

// ======================= PARSE BARIS =======================

class ImportRow {
  ImportRow(this.date, this.desc, this.amount, this.isExpense, this.key);
  final DateTime date;
  final String desc;
  final double amount;
  final bool isExpense;
  final String key;
}

class ImportResult {
  ImportResult(this.rows, this.invalid);
  final List<ImportRow> rows;
  final int invalid;
}

ImportResult parseRows(
  List<List<String>> rows, {
  required int header,
  int? cDate,
  int? cDesc,
  int? cAmount,
  int? cDebit,
  int? cCredit,
  required bool twoCols,
  required bool flip,
  String? dateFmt,
}) {
  final out = <ImportRow>[];
  final seen = <String, int>{};
  var invalid = 0;
  for (var i = header + 1; i < rows.length; i++) {
    final r = rows[i];
    String cell(int? c) => (c != null && c < r.length) ? r[c].trim() : '';
    final d = parseDate(cell(cDate), dateFmt);
    if (d == null) {
      invalid++;
      continue;
    }
    double? amt;
    var isExpense = true;
    if (twoCols) {
      final db = parseMoney(cell(cDebit));
      final cr = parseMoney(cell(cCredit));
      if (db != null && db.abs() > 0) {
        amt = db.abs();
        isExpense = true;
      } else if (cr != null && cr.abs() > 0) {
        amt = cr.abs();
        isExpense = false;
      }
    } else {
      final v = parseMoney(cell(cAmount));
      if (v != null && v != 0) {
        isExpense = flip ? v > 0 : v < 0;
        amt = v.abs();
      }
    }
    if (amt == null) {
      invalid++;
      continue;
    }
    final desc = cell(cDesc);
    final base = '${d.toIso8601String().substring(0, 10)}|${amt.round()}|$isExpense|${desc.toLowerCase()}';
    final n = (seen[base] ?? 0) + 1;
    seen[base] = n;
    out.add(ImportRow(d, desc, amt, isExpense, '$base|$n'));
  }
  return ImportResult(out, invalid);
}
