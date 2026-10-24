import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kartu info founder Tertata (nama, email, Instagram). Ketuk baris untuk menyalin.
class FounderInfo extends StatelessWidget {
  const FounderInfo({super.key});

  static const name = 'Muhammad Ikhsan';
  static const email = 'ican3192@gmail.com';
  static const instagram = '@tertata.app';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget row(IconData icon, String label, String value, {String? copy}) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: copy == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: copy));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('$label disalin')));
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
              if (copy != null) Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FOUNDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: cs.primary)),
        const SizedBox(height: 4),
        row(Icons.person_outline, 'Nama', name),
        row(Icons.mail_outline, 'Email', email, copy: email),
        row(Icons.alternate_email, 'Instagram', instagram, copy: instagram),
      ]),
    );
  }
}
