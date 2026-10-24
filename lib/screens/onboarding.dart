import 'package:flutter/material.dart';
import '../common.dart';
import '../services/security.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final page = PageController();
  final ctrls = <String, TextEditingController>{};
  int i = 0;

  @override
  void dispose() {
    page.dispose();
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int n) => page.animateToPage(n, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  Future<void> _finish() async {
    final s = AppScope.of(context);
    for (final w in s.wallets) {
      final c = ctrls[w.id];
      final v = c == null ? 0.0 : parseAmount(c.text);
      if (v != w.initial) {
        w.initial = v;
        await s.saveWallet(w);
      }
    }
    await s.finishOnboarding();
  }

  Widget _feature(BuildContext context, IconData icon, String title, String sub, {Widget? leading}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        leading ?? IconBadge(icon: icon, color: cs.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final last = i == 2;

    final welcome = ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 24),
      const Center(child: FadeSlideIn(child: BrandLogo(height: 150))),
      const SizedBox(height: 20),
      Text('Selamat datang di Tertata',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Catat, kelola, dan pahami keuangan Anda dengan tenang.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
      const SizedBox(height: 28),
      FadeSlideIn(index: 1, child: _feature(context, Icons.edit_note, 'Catat cepat', 'Ketik kalimat biasa seperti "kopi 25rb" atau scan struk.')),
      FadeSlideIn(index: 2, child: _feature(context, Icons.donut_large, 'Anggaran & laporan', 'Pantau pengeluaran per kategori dan tren bulanan.')),
      FadeSlideIn(index: 3, child: _feature(context, Icons.chat_bubble_outline_rounded, 'Asisten AI (opsional)', 'Tanya jawab, rapikan kategori, dan saran anggaran.', leading: const AiMark(size: 42))),
      const SizedBox(height: 16),
      AppCard(
        color: cs.primary.soft(.07),
        child: const Text('Aplikasi ini hanya mencatat dan mengelola keuangan. Tidak ada uang yang dibayar atau dipindahkan sungguhan.'),
      ),
    ]);

    final balances = ListView(padding: const EdgeInsets.all(24), children: [
      Text('Saldo awal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Isi saldo dompet Anda saat ini agar total saldo sesuai. Boleh dikosongkan dan diubah nanti.', style: TextStyle(color: cs.onSurfaceVariant)),
      const SizedBox(height: 20),
      for (final w in s.wallets)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: ctrls.putIfAbsent(w.id, () => TextEditingController(text: w.initial == 0 ? '' : angka(w.initial))),
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahFormatter()],
            decoration: fieldDeco(context, w.name, prefix: currencySymbol, icon: kIcons[w.icon]),
          ),
        ),
      const SizedBox(height: 8),
      const Text('Simbol mata uang', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final c in kCurrencies) ChoiceChip(label: Text(c.trim()), selected: s.currency == c, onSelected: (_) => s.setCurrency(c)),
      ]),
    ]);

    final ready = ListView(padding: const EdgeInsets.all(24), children: [
      Text('Siap dipakai', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Dua hal opsional sebelum mulai.', style: TextStyle(color: cs.onSurfaceVariant)),
      const SizedBox(height: 20),
      AppCard(
        child: Row(children: [
          const IconBadge(icon: Icons.lock_outline, color: kTransfer),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kunci dengan PIN 6 digit', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Lindungi data Anda. Biometrik bisa diaktifkan setelahnya.'),
            ]),
          ),
          s.pinEnabled
              ? const Icon(Icons.check_circle, color: kIncome)
              : OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen())),
                  child: const Text('Atur'),
                ),
        ]),
      ),
      AppCard(
        child: Row(children: [
          const AiMark(size: 42),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Asisten AI', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Aktifkan nanti di Lainnya > Pengaturan dengan kunci API gratis (Gemini/Groq).'),
            ]),
          ),
        ]),
      ),
    ]);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: const Text('Lewati')),
          ),
          Expanded(child: PageView(controller: page, onPageChanged: (v) => setState(() => i = v), children: [welcome, balances, ready])),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(children: [
              Row(children: [
                for (var k = 0; k < 3; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == k ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: i == k ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const Spacer(),
              FilledButton(
                onPressed: last ? _finish : () => _go(i + 1),
                child: Text(last ? 'Mulai' : 'Lanjut'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
