import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common.dart';
import '../services/ai.dart';
import '../services/ai_providers.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});
  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final keyCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final baseCtrl = TextEditingController();
  late String provider;
  bool obscure = true;
  bool testing = false;
  bool _init = false;
  String? error;

  AiProvider get prov => aiProviderById(provider);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.of(context);
    provider = s.aiProvider;
    modelCtrl.text = s.aiModel;
    baseCtrl.text = s.aiBaseUrl;
  }

  @override
  void dispose() {
    keyCtrl.dispose();
    modelCtrl.dispose();
    baseCtrl.dispose();
    super.dispose();
  }

  void _pick(AiProvider p) {
    final s = AppScope.of(context);
    setState(() {
      provider = p.id;
      error = null;
      modelCtrl.text = p.id == s.aiProvider ? s.aiModel : p.defaultModel;
      if (p.custom) baseCtrl.text = s.aiProvider == 'custom' ? s.aiBaseUrl : '';
    });
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final sameProvider = provider == s.aiProvider && s.aiKeySet;
    var k = keyCtrl.text.trim();
    if (k.isEmpty && sameProvider) k = s.aiKey!; // hanya mengubah model/alamat
    if (k.isEmpty) {
      setState(() => error = 'Tempel kunci API dari ${prov.name} dulu.');
      return;
    }
    final model = modelCtrl.text.trim().isEmpty ? prov.defaultModel : modelCtrl.text.trim();
    final base = prov.custom ? baseCtrl.text.trim() : prov.baseUrl;
    setState(() {
      testing = true;
      error = null;
    });
    final err = await AiService.test(base, k, model);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        testing = false;
        error = err;
      });
      return;
    }
    await s.setAiConfig(provider: provider, model: model, baseUrl: prov.custom ? base : null);
    final stored = await s.setAiKey(k);
    await s.setAiConsent(true);
    if (!mounted) return;
    keyCtrl.clear();
    setState(() => testing = false);
    snack(context, stored ? 'AI aktif. Kunci tersimpan terenkripsi di perangkat.' : 'AI aktif, tetapi kunci hanya tersimpan selama sesi ini.');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = prov;
    final switching = provider != s.aiProvider && s.aiKeySet;
    return Scaffold(
      appBar: AppBar(title: const Text('Asisten AI NACI')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        AppCard(
          color: cs.primary.soft(.07),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AiMark(size: 40),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Asisten dapat menjawab pertanyaan tentang keuangan Anda, mencatat transaksi dari kalimat, merapikan kategori, dan menyarankan anggaran. Semua perubahan hanya berupa draf yang Anda konfirmasi.',
                style: TextStyle(height: 1.4),
              ),
            ),
          ]),
        ),
        const SectionHeader('Penyedia AI (ada paket gratis)'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(children: [
            for (final x in kAiProviders)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(x.tagline),
                value: x.id,
                groupValue: provider,
                onChanged: (_) => _pick(x),
              ),
          ]),
        ),
        const SectionHeader('Kunci API'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(s.aiKeySet ? Icons.check_circle : Icons.circle_outlined, size: 18, color: s.aiKeySet ? kIncome : cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.aiKeySet ? 'Aktif · ${s.aiLabel}' : 'Belum diatur', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: fieldDeco(context, s.aiKeySet && !switching ? 'Ganti kunci API (opsional)' : 'Kunci API ${p.name}', hint: p.keyHint, icon: Icons.key).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            if (switching)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Anda memilih penyedia baru. Tempel kunci API milik ${p.name}; kunci lama tidak akan dikirim ke sana.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ),
            if (error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: cs.error, fontSize: 13))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: testing ? null : _save,
                  child: testing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan & uji'),
                ),
              ),
              if (s.aiKeySet) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    if (await confirmDialog(context, 'Hapus kunci API dari perangkat ini?')) await s.setAiKey(null);
                  },
                  child: const Text('Hapus'),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            if (!p.custom)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    'Buat kunci gratis di ${p.keyUrl} (cukup login, tanpa kartu kredit untuk paket gratis). Kunci hanya milik Anda; jangan dibagikan.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Salin alamat',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://${p.keyUrl}'));
                    snack(context, 'Alamat disalin, buka di browser');
                  },
                ),
              ])
            else
              Text('Isi alamat dasar API (mis. https://api.openai.com/v1) dan nama model di bawah.', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SectionHeader('Model'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.custom) ...[
              TextField(
                controller: baseCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: fieldDeco(context, 'Alamat dasar API', hint: 'https://…/v1', icon: Icons.link),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: modelCtrl,
              autocorrect: false,
              enableSuggestions: false,
              decoration: fieldDeco(context, 'Nama model', hint: p.defaultModel.isEmpty ? 'mis. gpt-4o-mini' : p.defaultModel, icon: Icons.memory),
            ),
            if (p.models.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in p.models.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: modelCtrl.text.trim() == e.key,
                    onSelected: (_) => setState(() => modelCtrl.text = e.key),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Daftar model gratis dari penyedia bisa berganti. Jika model tidak ditemukan, ketik nama model terbaru dari dokumentasi mereka.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!p.vision)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Penyedia ini hanya membaca teks. Untuk scan struk, pakai Google Gemini.', style: Theme.of(context).textTheme.bodySmall),
              ),
          ]),
        ),
        const SectionHeader('Batas harian'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Terpakai hari ini: ${s.aiUsedToday}${s.aiDailyLimit > 0 ? ' / ${s.aiDailyLimit}' : ''} permintaan'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final v in const [20, 60, 150, 0])
                ChoiceChip(
                  label: Text(v == 0 ? 'Tanpa batas' : '$v / hari'),
                  selected: s.aiDailyLimit == v,
                  onSelected: (_) => s.setPrefInt('ai_limit', v),
                ),
            ]),
            const SizedBox(height: 10),
            Text('Paket gratis punya kuota sendiri dari penyedia. Batas ini membantu agar kuota tidak cepat habis.', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SectionHeader('Privasi'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Izinkan AI membaca data keuangan'),
              subtitle: Text('Ringkasan dan transaksi relevan dikirim ke ${s.aiKeySet ? s.aiProviderInfo.name : 'penyedia AI pilihan Anda'} hanya saat Anda bertanya.'),
              value: s.aiConsent,
              onChanged: (v) => s.setAiConsent(v),
            ),
            const Divider(),
            Text(
              'Kunci API disimpan terenkripsi di perangkat dan tidak ikut dalam file cadangan. Seluruh data transaksi tetap tersimpan lokal. '
              'Penyedia paket gratis umumnya boleh memakai data yang dikirim untuk meningkatkan produk mereka; baca kebijakan penyedia sebelum mengirim data sensitif.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }
}
