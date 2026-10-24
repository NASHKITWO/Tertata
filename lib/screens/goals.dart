import 'dart:math';
import 'package:flutter/material.dart';
import '../common.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  Future<void> _edit(BuildContext context, {Goal? g}) async {
    final s = AppScope.of(context);
    final name = TextEditingController(text: g?.name ?? '');
    final target = TextEditingController(text: g == null ? '' : angka(g.target));
    DateTime? deadline = g?.deadline;
    var color = g?.color ?? kColorValues[s.goals.length % kColorValues.length];
    var icon = g?.icon ?? 10;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(g == null ? 'Target Baru' : 'Ubah Target'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: fieldDeco(ctx, 'Nama target', hint: 'mis. Dana darurat')),
              const SizedBox(height: 12),
              TextField(
                controller: target,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahFormatter()],
                decoration: fieldDeco(ctx, 'Jumlah target', prefix: currencySymbol),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(deadline == null ? 'Tenggat (opsional)' : tgl(deadline!)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: deadline ?? DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) set(() => deadline = d);
                },
              ),
              const SizedBox(height: 16),
              StylePicker(color: color, icon: icon, onColor: (v) => set(() => color = v), onIcon: (v) => set(() => icon = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final t = parseAmount(target.text);
                if (name.text.trim().isEmpty || t <= 0) return;
                s.saveGoal(Goal(
                  id: g?.id ?? s.uid(),
                  name: name.text.trim(),
                  target: t,
                  saved: g?.saved ?? 0,
                  deadline: deadline,
                  color: color,
                  icon: icon,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(BuildContext context, Goal g) async {
    final s = AppScope.of(context);
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(g.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahFormatter()],
          decoration: fieldDeco(ctx, 'Nominal', prefix: currencySymbol),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final a = parseAmount(ctrl.text);
              if (a <= 0) return;
              g.saved = max(0.0, g.saved - a);
              s.saveGoal(g);
              Navigator.pop(ctx);
            },
            child: const Text('Tarik'),
          ),
          FilledButton(
            onPressed: () {
              final a = parseAmount(ctrl.text);
              if (a <= 0) return;
              g.saved += a;
              s.saveGoal(g);
              Navigator.pop(ctx);
            },
            child: const Text('Setor'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Target Tabungan')),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Target'),
      ),
      body: s.goals.isEmpty
          ? const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Belum ada target',
              subtitle: 'Buat target seperti dana darurat, liburan, atau gadget baru.',
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
              for (final g in s.goals) _card(context, s, g),
            ]),
    );
  }

  Widget _card(BuildContext context, AppState s, Goal g) {
    final color = Color(g.color);
    final done = g.saved >= g.target;
    final ratio = (g.saved / g.target).clamp(0.0, 1.0);
    String? hint;
    if (!done && g.deadline != null) {
      final days = g.deadline!.difference(DateTime.now()).inDays;
      if (days < 0) {
        hint = 'Tenggat ${tgl(g.deadline!)} · terlewat';
      } else {
        final months = max(1, (days / 30).ceil());
        hint = 'Tenggat ${tgl(g.deadline!)} · $days hari lagi · sisihkan ≈ ${rp((g.target - g.saved) / months)}/bulan';
      }
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon: kIcons[g.icon], color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          if (done) const Icon(Icons.check_circle, color: kIncome),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                _edit(context, g: g);
              } else if (v == 'delete' && await confirmDialog(context, 'Hapus target ${g.name}?')) {
                s.deleteGoal(g.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Ubah')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: ratio, color: color, backgroundColor: color.soft(.14), minHeight: 10, semanticsLabel: 'Target ${g.name}', semanticsValue: '${(ratio * 100).round()} persen tercapai'),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${rp(g.saved)} / ${rp(g.target)}'),
          Text('${(ratio * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => _move(context, g),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Setor / Tarik'),
          ),
        ),
      ]),
    );
  }
}
