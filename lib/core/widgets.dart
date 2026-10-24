import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'format.dart';
import 'theme.dart';

/// Kartu: latar permukaan hangat, garis tipis, bayangan sangat lembut (tema terang).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(18);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          color: color == null ? surfaceOf(context) : Color.alphaBlend(color!, surfaceOf(context)),
          borderRadius: r,
          border: Border.all(color: cs.outlineVariant.soft(dark ? .55 : .6)),
          // Bayangan tipis hangat memberi kedalaman halus; di tema gelap dimatikan.
          boxShadow: dark
              ? null
              : const [BoxShadow(color: Color(0x14403020), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Dahulu memunculkan anak dengan animasi; kini langsung menampilkan anak agar antarmuka tenang.
/// Parameter dipertahankan supaya pemanggil lama tetap berfungsi.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.dy = 18});
  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context) => child;
}

/// Logo Tertata tanpa latar. Varian gelap otomatis dipakai di mode gelap (teks logo jadi terang).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 120, this.mark = false});
  final double height;
  final bool mark;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = mark ? 'assets/logo_mark.png' : (dark ? 'assets/logo_full_dark.png' : 'assets/logo_full.png');
    return Image.asset(asset, height: height, fit: BoxFit.contain, filterQuality: FilterQuality.high);
  }
}

/// Judul halaman utama (Transaksi, Analisis, Lainnya) dengan keterangan kecil di atasnya.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 12, 12, 4)});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            if (subtitle != null) const SizedBox(height: 2),
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface, letterSpacing: -.1),
          ),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.primary.soft(.1), borderRadius: BorderRadius.circular(24)),
            child: Icon(icon, size: 32, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 42});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.soft(.14), borderRadius: BorderRadius.circular(size * .34)),
        child: Icon(icon, color: color, size: size * .5),
      ),
    );
  }
}

class PeriodNav extends StatelessWidget {
  const PeriodNav({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.soft(.55)),
      ),
      child: Row(children: [
        IconButton(tooltip: 'Sebelumnya', onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Center(child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        ),
        IconButton(tooltip: 'Berikutnya', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ]),
    );
  }
}

class RupiahFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digits.length > 13) digits = digits.substring(0, 13);
    final t = angka(int.parse(digits));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

double parseAmount(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;

InputDecoration fieldDeco(BuildContext context, String label, {String? prefix, IconData? icon, String? hint}) {
  final cs = Theme.of(context).colorScheme;
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: cs.surfaceContainerHighest.soft(.4),
    border: b(Colors.transparent),
    enabledBorder: b(Colors.transparent),
    focusedBorder: b(cs.primary, 1.6),
  );
}

Future<bool> confirmDialog(BuildContext context, String msg, {String ok = 'Hapus', String title = 'Konfirmasi'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

void undoSnack(BuildContext context, String msg, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'URUNGKAN', onPressed: onUndo),
    ));
}

class StylePicker extends StatelessWidget {
  const StylePicker({super.key, required this.color, required this.icon, required this.onColor, required this.onIcon});
  final int color;
  final int icon;
  final ValueChanged<int> onColor;
  final ValueChanged<int> onIcon;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in kColorValues)
          GestureDetector(
            onTap: () => onColor(c),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Color(c),
              child: color == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < kIcons.length; i++)
          GestureDetector(
            onTap: () => onIcon(i),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: icon == i ? Color(color) : Colors.grey.soft(.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(kIcons[i], size: 19, color: icon == i ? Colors.white : Colors.grey),
            ),
          ),
      ]),
    ]);
  }
}


/// Cincin progres kecil dengan teks di tengah (mis. persen anggaran terpakai).
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.value, required this.color, required this.label, this.size = 64, this.semanticLabel});
  final String? semanticLabel;
  final double value;
  final Color color;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Indikator',
      value: label,
      excludeSemantics: true,
      child: SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.soft(.14),
          ),
        ),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * .22)),
      ]),
    ));
  }
}

/// Lencana kecil berwarna untuk status singkat.
class SoftChip extends StatelessWidget {
  const SoftChip({super.key, required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.soft(.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
