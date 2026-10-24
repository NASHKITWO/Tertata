import 'package:flutter/material.dart';
import '../common.dart';

/// Satu faktor penilaian kesehatan keuangan (skor 0..1).
class HealthFactor {
  const HealthFactor({
    required this.title,
    required this.score,
    required this.weight,
    required this.detail,
    required this.tip,
    required this.icon,
  });
  final String title;
  final double score;
  final double weight;
  final String detail;
  final String tip;
  final IconData icon;
}

class Health {
  const Health(this.factors);
  final List<HealthFactor> factors;

  int get score {
    var w = 0.0;
    var t = 0.0;
    for (final f in factors) {
      w += f.weight;
      t += f.score * f.weight;
    }
    return w == 0 ? 0 : (t / w * 100).round().clamp(0, 100).toInt();
  }

  String get grade {
    final v = score;
    if (v >= 80) return 'Sangat sehat';
    if (v >= 60) return 'Sehat';
    if (v >= 40) return 'Cukup';
    return 'Perlu perhatian';
  }

  Color get color {
    final v = score;
    if (v >= 60) return kIncome;
    if (v >= 40) return kWarn;
    return kDanger;
  }
}

/// Menghitung skor kesehatan keuangan dari data lokal (tanpa jaringan).
Health computeHealth(AppState s) {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 2);
  final to = DateTime(now.year, now.month + 1);
  final inc = s.sumBetween(from, to, TxType.income);
  final exp = s.sumBetween(from, to, TxType.expense);

  // rata-rata pengeluaran per bulan (hanya bulan yang ada pengeluaran)
  var active = 0;
  for (var i = 0; i < 3; i++) {
    final a = DateTime(now.year, now.month - i);
    if (s.sumBetween(a, DateTime(a.year, a.month + 1), TxType.expense) > 0) active++;
  }
  final avgExp = active == 0 ? 0.0 : exp / active;

  // 1) Tabungan
  final rate = inc > 0 ? (inc - exp) / inc : (exp > 0 ? -1.0 : 0.0);
  final saveScore = (rate / 0.2).clamp(0.0, 1.0).toDouble();
  final saving = HealthFactor(
    title: 'Tingkat tabungan',
    score: saveScore,
    weight: 3,
    icon: Icons.savings_outlined,
    detail: inc <= 0
        ? 'Belum ada pemasukan tercatat 3 bulan ini'
        : (rate >= 0 ? 'Anda menyisihkan ${(rate * 100).toStringAsFixed(0)}% dari pemasukan' : 'Pengeluaran melebihi pemasukan ${(-rate * 100).toStringAsFixed(0)}%'),
    tip: rate >= 0.2 ? 'Bagus, pertahankan minimal 20%.' : 'Targetkan menyisihkan 20% pemasukan di awal bulan, sebelum dibelanjakan.',
  );

  // 2) Dana darurat (dompet likuid: bukan investasi/kartu kredit)
  final liquid = s.activeWallets.where((w) => w.type != 'invest' && w.type != 'card').fold<double>(0.0, (a, w) => a + s.balanceOf(w.id));
  final months = avgExp > 0 ? liquid / avgExp : (liquid > 0 ? 6.0 : 0.0);
  final emergency = HealthFactor(
    title: 'Dana darurat',
    score: (months / 6).clamp(0.0, 1.0).toDouble(),
    weight: 3,
    icon: Icons.shield_outlined,
    detail: avgExp > 0 ? 'Saldo likuid cukup untuk ${months.toStringAsFixed(1)} bulan pengeluaran' : 'Belum cukup data pengeluaran',
    tip: months >= 6 ? 'Dana darurat Anda sudah ideal (6 bulan atau lebih).' : 'Buat target tabungan "Dana darurat" sebesar 6x pengeluaran bulanan (${rp(avgExp * 6)}).',
  );

  // 3) Disiplin anggaran bulan ini
  final budgets = s.budgets;
  var ok = 0;
  for (final b in budgets) {
    if (s.spentCat(b.categoryId, now) <= s.budgetLimit(b, now)) ok++;
  }
  final budget = HealthFactor(
    title: 'Disiplin anggaran',
    score: budgets.isEmpty ? 0.5 : ok / budgets.length,
    weight: 2,
    icon: Icons.pie_chart_outline,
    detail: budgets.isEmpty ? 'Belum ada anggaran' : '$ok dari ${budgets.length} anggaran masih aman bulan ini',
    tip: budgets.isEmpty ? 'Buat anggaran untuk 2-3 kategori terbesar agar pengeluaran terkendali.' : (ok == budgets.length ? 'Semua anggaran aman, lanjutkan.' : 'Kurangi belanja pada kategori yang sudah melewati batas.'),
  );

  // 4) Beban hutang
  final owed = s.debts.where((d) => !d.settled && !d.owedToMe).fold<double>(0.0, (a, d) => a + d.remaining);
  final ratio = owed == 0 ? 0.0 : (s.netWorth > 0 ? owed / s.netWorth : 1.0);
  final debt = HealthFactor(
    title: 'Beban hutang',
    score: (1 - ratio).clamp(0.0, 1.0).toDouble(),
    weight: 2,
    icon: Icons.handshake_outlined,
    detail: owed == 0 ? 'Tidak ada hutang berjalan' : 'Hutang ${rp(owed)} (${(ratio * 100).toStringAsFixed(0)}% dari total saldo)',
    tip: owed == 0 ? 'Bebas hutang, kondisi yang sangat baik.' : 'Lunasi hutang yang jatuh tempo paling dekat lebih dulu.',
  );

  return Health([saving, emergency, budget, debt]);
}

class UpcomingItem {
  const UpcomingItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.income,
    required this.icon,
    required this.color,
    this.overdue = false,
  });
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool income;
  final IconData icon;
  final Color color;
  final bool overdue;
}

/// Tagihan, transaksi berulang, dan hutang/piutang jatuh tempo dalam [days] hari ke depan.
List<UpcomingItem> upcoming(AppState s, {int days = 30}) {
  final today = dayOnly(DateTime.now());
  final limit = DateTime(today.year, today.month, today.day + days + 1);
  final out = <UpcomingItem>[];

  for (final r in s.recurrings.where((r) => r.active && r.type != TxType.transfer)) {
    var d = r.nextDate;
    var guard = 0;
    while (d.isBefore(limit) && guard < 60) {
      guard++;
      if (r.endDate != null && d.isAfter(r.endDate!)) break;
      if (!d.isBefore(today)) {
        final c = s.cat(r.categoryId);
        final inc = r.type == TxType.income;
        out.add(UpcomingItem(
          date: dayOnly(d),
          title: c?.name ?? (r.note.isEmpty ? 'Transaksi berulang' : r.note),
          subtitle: 'Berulang ${r.freq.label.toLowerCase()}${r.note.isEmpty ? '' : ' · ${r.note}'}',
          amount: r.amount,
          income: inc,
          icon: inc ? Icons.south_west : Icons.event_repeat,
          color: inc ? kIncome : Color(c?.color ?? 0xFFF2506E),
        ));
      }
      d = nextOccurrence(d, r.freq, r.anchorDay);
    }
  }

  for (final d in s.debts.where((d) => !d.settled && d.due != null)) {
    final due = dayOnly(d.due!);
    if (due.isBefore(limit)) {
      out.add(UpcomingItem(
        date: due.isBefore(today) ? today : due,
        title: d.owedToMe ? 'Piutang dari ${d.person}' : 'Hutang ke ${d.person}',
        subtitle: due.isBefore(today) ? 'Terlambat sejak ${tgl(due)}' : 'Jatuh tempo ${tgl(due)}',
        amount: d.remaining,
        income: d.owedToMe,
        icon: Icons.handshake_outlined,
        color: kWarn,
        overdue: due.isBefore(today),
      ));
    }
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}
