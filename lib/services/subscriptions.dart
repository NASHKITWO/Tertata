import '../data/models.dart';

/// Tagihan rutin (langganan) yang terdeteksi dari pola catatan pengeluaran.
class Subscription {
  const Subscription({
    required this.key,
    required this.name,
    required this.amount,
    required this.freq,
    required this.lastDate,
    required this.nextDate,
    required this.count,
    required this.walletId,
    this.categoryId,
  });
  final String key;
  final String name;
  final double amount;
  final Freq freq;
  final DateTime lastDate;
  final DateTime nextDate;
  final int count;
  final String walletId;
  final String? categoryId;

  double get monthlyCost => freq == Freq.weekly ? amount * 52 / 12 : amount;
  double get yearlyCost => monthlyCost * 12;
}

/// Menyeragamkan catatan: huruf kecil, tanpa angka/tanda baca, spasi tunggal.
String normalizeMerchant(String note) {
  return note
      .toLowerCase()
      .replaceAll(RegExp(r'[0-9]+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\s&]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Mencari pengeluaran yang berulang tiap bulan/minggu dengan nominal mirip.
/// Transaksi hasil aturan berulang dan arus netral (hutang) diabaikan.
/// [alreadyRecurring] berisi catatan ternormalisasi yang sudah punya aturan berulang.
List<Subscription> detectSubscriptions(
  Iterable<Tx> txs, {
  DateTime? now,
  Set<String> alreadyRecurring = const {},
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final groups = <String, List<Tx>>{};
  for (final t in txs) {
    if (t.type != TxType.expense || t.neutral || t.recurringId != null) continue;
    final k = normalizeMerchant(t.note);
    if (k.length < 3 || alreadyRecurring.contains(k)) continue;
    groups.putIfAbsent(k, () => []).add(t);
  }

  final out = <Subscription>[];
  groups.forEach((key, list) {
    final sorted = [...list]..sort((a, b) => a.date.compareTo(b.date));
    // satu transaksi per hari
    final uniq = <Tx>[];
    for (final t in sorted) {
      if (uniq.isNotEmpty) {
        final p = uniq.last.date;
        if (p.year == t.date.year && p.month == t.date.month && p.day == t.date.day) continue;
      }
      uniq.add(t);
    }
    if (uniq.length < 3) return;

    final gaps = <int>[];
    for (var i = 1; i < uniq.length; i++) {
      final a = DateTime(uniq[i - 1].date.year, uniq[i - 1].date.month, uniq[i - 1].date.day);
      final b = DateTime(uniq[i].date.year, uniq[i].date.month, uniq[i].date.day);
      gaps.add(b.difference(a).inDays);
    }
    final sg = [...gaps]..sort();
    final median = sg[sg.length ~/ 2];
    Freq? f;
    var lo = 0;
    var hi = 0;
    if (median >= 26 && median <= 35) {
      f = Freq.monthly;
      lo = 24;
      hi = 38;
    } else if (median >= 6 && median <= 8) {
      f = Freq.weekly;
      lo = 5;
      hi = 9;
    }
    if (f == null) return;
    final okGaps = gaps.where((g) => g >= lo && g <= hi).length;
    if (okGaps / gaps.length < .75) return;

    final amounts = uniq.map((t) => t.amount).toList()..sort();
    final medAmount = amounts[amounts.length ~/ 2];
    if (medAmount <= 0) return;
    final okAmt = uniq.where((t) => (t.amount - medAmount).abs() <= medAmount * .2).length;
    if (okAmt / uniq.length < .8) return;

    final last = uniq.last;
    final lastDay = DateTime(last.date.year, last.date.month, last.date.day);
    if (today.difference(lastDay).inDays > median * 1.6) return; // sudah berhenti

    var next = f == Freq.monthly ? nextOccurrence(lastDay, Freq.monthly, lastDay.day) : lastDay.add(const Duration(days: 7));
    var guard = 0;
    while (next.isBefore(today) && guard++ < 60) {
      next = f == Freq.monthly ? nextOccurrence(next, Freq.monthly, lastDay.day) : next.add(const Duration(days: 7));
    }

    final name = last.note.trim();
    out.add(Subscription(
      key: key,
      name: name.isEmpty ? key : name,
      amount: medAmount,
      freq: f,
      lastDate: lastDay,
      nextDate: next,
      count: uniq.length,
      walletId: last.walletId,
      categoryId: last.categoryId,
    ));
  });

  out.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
  return out;
}
