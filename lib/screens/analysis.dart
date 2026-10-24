import 'package:flutter/material.dart';
import '../core/widgets.dart';
import 'budgets.dart';
import 'insights.dart';
import 'reports.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int seg = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        const PageTitle('Analisis', subtitle: 'Laporan, anggaran, dan wawasan'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Laporan')),
                ButtonSegment(value: 1, label: Text('Anggaran')),
                ButtonSegment(value: 2, label: Text('Wawasan')),
              ],
              selected: {seg},
              onSelectionChanged: (v) => setState(() => seg = v.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: seg, children: const [ReportsPage(), BudgetsPage(), InsightsPage()]),
        ),
      ]),
    );
  }
}
