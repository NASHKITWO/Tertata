import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../common.dart';
import '../services/pdf_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool isYear = false;
  bool expenseMode = true;
  DateTime anchor = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int d) => setState(() {
        anchor = isYear ? DateTime(anchor.year + d, anchor.month) : DateTime(anchor.year, anchor.month + d);
      });

  String _delta(double cur, double prev) {
    if (prev == 0) return '—';
    final ch = (cur - prev) / prev * 100;
    return '${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final from = isYear ? DateTime(anchor.year) : DateTime(anchor.year, anchor.month);
    final to = isYear ? DateTime(anchor.year + 1) : DateTime(anchor.year, anchor.month + 1);
    final pFrom = isYear ? DateTime(anchor.year - 1) : DateTime(anchor.year, anchor.month - 1);

    final inc = s.sumBetween(from, to, TxType.income);
    final exp = s.sumBetween(from, to, TxType.expense);
    final prevExp = s.sumBetween(pFrom, from, TxType.expense);
    final net = inc - exp;

    final end = now.isBefore(to) ? now : to;
    var elapsed = end.difference(from).inDays + 1;
    if (elapsed < 1) elapsed = 1;
    final isCurrentMonth = !isYear && sameMonth(anchor, now);
    final projected = (isCurrentMonth && elapsed >= 3) ? exp / elapsed * DateTime(anchor.year, anchor.month + 1, 0).day : null;

    final months = isYear
        ? [for (var i = 1; i <= 12; i++) DateTime(anchor.year, i)]
        : [for (var i = 5; i >= 0; i--) DateTime(anchor.year, anchor.month - i)];
    final incs = months.map((m) => s.sumBetween(m, DateTime(m.year, m.month + 1), TxType.income)).toList();
    final exps = months.map((m) => s.sumBetween(m, DateTime(m.year, m.month + 1), TxType.expense)).toList();
    final worth = months.map((m) => s.netWorthBefore(DateTime(m.year, m.month + 1))).toList();
    final maxBar = [...incs, ...exps, 1.0].reduce(max);

    final type = expenseMode ? TxType.expense : TxType.income;
    final cat = s.byCategory(from, to, type).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = cat.fold(0.0, (a, e) => a + e.value);
    Color colorOf(String? id) => Color(s.cat(id)?.color ?? 0xFF9E9E9E);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Bulanan'), icon: Icon(Icons.calendar_view_month)),
              ButtonSegment(value: true, label: Text('Tahunan'), icon: Icon(Icons.calendar_today)),
            ],
            selected: {isYear},
            onSelectionChanged: (v) => setState(() => isYear = v.first),
          ),
          const SizedBox(height: 8),
          PeriodNav(label: isYear ? '${anchor.year}' : bulan(anchor), onPrev: () => _shift(-1), onNext: () => _shift(1)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(children: [
              Row(children: [
                Expanded(child: _col(context, 'Pemasukan', rp(inc), kIncome)),
                Expanded(child: _col(context, 'Pengeluaran', rp(exp), kExpense)),
                Expanded(child: _col(context, 'Selisih', '${net >= 0 ? '' : '-'}${rp(net.abs())}', net >= 0 ? kIncome : kExpense)),
              ]),
              const Divider(height: 24),
              Text(
                'Pengeluaran ${_delta(exp, prevExp)} vs periode lalu · rata-rata ${rp(exp / elapsed)}/hari${projected != null ? ' · proyeksi akhir bulan ${rp(projected)}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const SectionHeader('Berdasarkan kategori'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Pengeluaran')),
              ButtonSegment(value: false, label: Text('Pemasukan')),
            ],
            selected: {expenseMode},
            onSelectionChanged: (v) => setState(() => expenseMode = v.first),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: cat.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada data pada periode ini')))
                : Column(children: [
                    SizedBox(
                      height: 210,
                      child: Stack(alignment: Alignment.center, children: [
                        PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 64,
                          sections: [
                            for (final e in cat)
                              PieChartSectionData(value: e.value, color: colorOf(e.key), radius: 28, showTitle: false),
                          ],
                        )),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(expenseMode ? 'Total keluar' : 'Total masuk', style: Theme.of(context).textTheme.labelSmall),
                          Text(rp(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    for (final e in cat.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          IconBadge(icon: kIcons[s.cat(e.key)?.icon ?? 20], color: colorOf(e.key), size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.cat(e.key)?.name ?? 'Tanpa kategori', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: total == 0 ? 0 : e.value / total,
                                  minHeight: 5,
                                  color: colorOf(e.key),
                                  backgroundColor: colorOf(e.key).soft(.12),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(rp(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${(e.value / total * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.labelSmall),
                          ]),
                        ]),
                      ),
                  ]),
          ),
          SectionHeader(isYear ? 'Arus kas per bulan' : 'Arus kas 6 bulan terakhir'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
            child: Column(children: [
              SizedBox(
                height: 190,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxBar * 1.15,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.soft(.2), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, meta) => Text(rpShort(v), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= months.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(bulanSingkat(months[i]), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      BarChartGroupData(x: i, barsSpace: 3, barRods: [
                        BarChartRodData(toY: incs[i], color: kIncome, width: isYear ? 6 : 11, borderRadius: BorderRadius.circular(3)),
                        BarChartRodData(toY: exps[i], color: kExpense, width: isYear ? 6 : 11, borderRadius: BorderRadius.circular(3)),
                      ]),
                  ],
                )),
              ),
              const SizedBox(height: 10),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.circle, size: 10, color: kIncome),
                SizedBox(width: 6),
                Text('Pemasukan'),
                SizedBox(width: 18),
                Icon(Icons.circle, size: 10, color: kExpense),
                SizedBox(width: 6),
                Text('Pengeluaran'),
              ]),
            ]),
          ),
          const SectionHeader('Tren kekayaan bersih'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
            child: SizedBox(
              height: 190,
              child: LineChart(LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.soft(.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Text(rpShort(v), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length || v != i.toDouble()) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(bulanSingkat(months[i]), style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < worth.length; i++) FlSpot(i.toDouble(), worth[i])],
                    isCurved: true,
                    color: cs.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: cs.primary.soft(.12)),
                  ),
                ],
              )),
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _exportPdf(s, from, to, isYear ? 'Tahun ${anchor.year}' : bulan(anchor)),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Ekspor laporan PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(AppState s, DateTime from, DateTime to, String label) async {
    try {
      final bytes = await buildReportPdf(s, from, to, label);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/laporan_${label.replaceAll(' ', '_').toLowerCase()}.pdf');
      await f.writeAsBytes(bytes);
      s.suppressLock = true;
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], subject: 'Laporan $label');
    } catch (_) {
      if (mounted) snack(context, 'Gagal membuat PDF');
    }
  }

  Widget _col(BuildContext context, String label, String value, Color color) {
    return Column(children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}
