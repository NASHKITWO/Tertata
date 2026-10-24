import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../common.dart';
import '../services/insights.dart';

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, .75 * pi, 1.5 * pi, false, p);
    p.color = color;
    canvas.drawArc(rect, .75 * pi, 1.5 * pi * value, false, p);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.value != value || old.color != color || old.track != track;
}

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final h = computeHealth(s);
    final color = h.color;
    final weakest = ([...h.factors]..sort((a, b) => a.score.compareTo(b.score))).first;

    return Scaffold(
      appBar: AppBar(title: const Text('Kesehatan Keuangan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(children: [
              SizedBox(
                height: 210,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: h.score / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CustomPaint(
                    painter: _ArcPainter(v, color, color.soft(.14)),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(v * 100).round()}', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -1, color: color)),
                        Text('dari 100', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
              SoftChip(text: h.grade, color: color, icon: Icons.favorite_outline),
              const SizedBox(height: 10),
              Text(
                'Skor dihitung dari data di perangkat ini: tabungan, dana darurat, anggaran, dan hutang. Ini panduan, bukan nasihat keuangan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
          AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(icon: Icons.tips_and_updates_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Langkah paling berdampak', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${weakest.title}: ${weakest.tip}'),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Rincian skor'),
          for (final f in h.factors) _factor(context, f),
        ],
      ),
    );
  }

  Widget _factor(BuildContext context, HealthFactor f) {
    final c = f.score >= .7 ? kIncome : (f.score >= .4 ? kWarn : kDanger);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon: f.icon, color: c, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Text('${(f.score * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: c)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: f.score.clamp(0.0, 1.0).toDouble(), color: c, backgroundColor: c.soft(.14), minHeight: 8),
        ),
        const SizedBox(height: 10),
        Text(f.detail, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(f.tip, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
