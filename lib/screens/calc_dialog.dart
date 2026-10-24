import 'package:flutter/material.dart';
import '../common.dart';
import '../core/calc.dart';

/// Dialog kalkulator nominal. Mengembalikan hasil (dibulatkan) bila pengguna menekan "Pakai", selain itu null.
Future<double?> showCalcDialog(BuildContext context, {String initial = ''}) {
  return showDialog<double>(context: context, builder: (_) => _CalcDialog(initial: initial));
}

class _CalcDialog extends StatefulWidget {
  const _CalcDialog({required this.initial});
  final String initial;

  @override
  State<_CalcDialog> createState() => _CalcDialogState();
}

class _CalcDialogState extends State<_CalcDialog> {
  late final TextEditingController ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _insert(String t) {
    final sel = ctrl.selection;
    final text = ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    ctrl.value = TextEditingValue(
      text: text.replaceRange(start, end, t),
      selection: TextSelection.collapsed(offset: start + t.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final v = evalExpression(ctrl.text);
    final result = v == null ? null : v.round();
    final ok = result != null && result > 0;
    return AlertDialog(
      title: const Text('Kalkulator'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: fieldDeco(context, 'Contoh: 25.000 + 7.500 × 2'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final t in const ['+', '−', '×', '÷', '(', ')'])
            OutlinedButton(onPressed: () => _insert(t == '−' ? '-' : t), child: Text(t)),
        ]),
        const SizedBox(height: 12),
        Text(
          ctrl.text.trim().isEmpty ? 'Ketik hitungan di atas.' : (v == null ? 'Hitungan belum lengkap atau tidak valid.' : '= ${rp(v.round())}'),
          style: TextStyle(fontWeight: FontWeight.w700, color: v == null && ctrl.text.trim().isNotEmpty ? kDanger : null),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: ok ? () => Navigator.pop(context, result!.toDouble()) : null, child: const Text('Pakai')),
      ],
    );
  }
}
