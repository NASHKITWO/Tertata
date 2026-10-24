import 'package:flutter/material.dart';

/// Ikon asisten di navigasi dan chip. Dahulu berupa dua bintang kilau; kini gelembung obrolan polos
/// agar terasa seperti fitur biasa, bukan "tempelan AI". Warna mengikuti IconTheme bila tidak ditentukan.
class AiSparkle extends StatelessWidget {
  const AiSparkle({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary;
    return Icon(Icons.chat_bubble_outline_rounded, size: size, color: c);
  }
}

/// Logo asisten AI: logo AI NACI di atas lencana putih. [animate] membuatnya berdenyut halus
/// (dipakai saat asisten sedang berpikir).
class AiMark extends StatefulWidget {
  const AiMark({super.key, this.size = 44, this.animate = false});
  final double size;
  final bool animate;

  @override
  State<AiMark> createState() => _AiMarkState();
}

class _AiMarkState extends State<AiMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AiMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _c.repeat(reverse: true);
      } else {
        _c.animateTo(0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: r,
          height: r,
          padding: EdgeInsets.all(r * .16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r * .30),
            color: Colors.white,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
          ),
          child: Transform.scale(
            scale: 1 + .06 * t,
            child: Image.asset('assets/ainaci_mark.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
          ),
        );
      },
    );
  }
}
