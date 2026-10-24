import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../common.dart';
import '../services/ai.dart';
import '../services/smart.dart';
import 'ai_settings.dart';

class ChatMsg {
  ChatMsg({
    required this.user,
    required this.text,
    List<Draft>? drafts,
    this.error = false,
    this.image = false,
    this.note = false,
  }) : drafts = drafts ?? [];
  final bool image;
  final bool user;
  final String text;
  final List<Draft> drafts;
  final bool error;
  final bool note; // pesan sistem lokal, tidak disimpan

  Map<String, dynamic> toJson() => {'u': user, 't': text, 'e': error, 'i': image};
  factory ChatMsg.fromJson(Map<String, dynamic> j) =>
      ChatMsg(user: j['u'] == true, text: (j['t'] ?? '') as String, error: j['e'] == true, image: j['i'] == true);
}

const _prompts = <(IconData, String, String)>[
  (Icons.insights_outlined, 'Ringkas keuangan bulan ini', 'Ringkas kondisi keuangan saya bulan ini: pemasukan, pengeluaran, kategori terbesar, dan beri 2-3 saran singkat.'),
  (Icons.trending_up, 'Cari pengeluaran yang boros', 'Bandingkan pengeluaran bulan ini dengan bulan lalu per kategori dan tunjukkan yang paling boros atau naik tajam.'),
  (Icons.label_outline, 'Rapikan kategori transaksi', 'Cek transaksi yang belum punya kategori atau masih di "Lainnya", lalu sarankan kategori yang tepat.'),
  (Icons.savings_outlined, 'Buat saran anggaran', 'Berdasarkan pengeluaran 3 bulan terakhir, sarankan anggaran bulanan per kategori yang realistis.'),
];

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final msgs = <ChatMsg>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  AiService? ai;
  bool busy = false;
  bool _loaded = false;
  final _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ai ??= AiService(AppScope.of(context));
    if (!_loaded) {
      _loaded = true;
      _loadChat(AppScope.of(context));
    }
  }

  void _loadChat(AppState s) {
    final raw = s.chatJson;
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).map((e) => ChatMsg.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isEmpty) return;
      msgs
        ..addAll(list)
        ..add(ChatMsg(user: false, text: 'Percakapan sebelumnya dipulihkan. Asisten tidak mengingat isinya; tanyakan ulang bila perlu.', note: true));
    } catch (_) {}
  }

  void _saveChat() {
    final keep = msgs.where((m) => !m.note).toList();
    final tail = keep.length > 40 ? keep.sublist(keep.length - 40) : keep;
    AppScope.of(context).saveChat(tail.isEmpty ? null : jsonEncode(tail.map((m) => m.toJson()).toList()));
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsPage()));

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || busy) return;
    final s = AppScope.of(context);

    if (s.aiKeySet && !s.aiConsent) {
      final ok = await confirmDialog(
        context,
        'Agar bisa menjawab, asisten mengirim ringkasan keuangan dan data transaksi yang relevan ke ${s.aiProviderInfo.name} memakai kunci API Anda. Data hanya dikirim saat Anda bertanya. Lanjutkan?',
        ok: 'Setuju',
        title: 'Izin penggunaan data',
      );
      if (!ok || !mounted) return;
      await s.setAiConsent(true);
      if (!mounted) return;
    }

    setState(() {
      msgs.add(ChatMsg(user: true, text: text));
      input.clear();
      busy = true;
    });
    _toBottom();
    _saveChat();

    ChatMsg reply;
    if (!s.aiKeySet) {
      final d = parseQuick(s, text);
      reply = d != null
          ? ChatMsg(user: false, text: 'Mode tanpa AI. Saya siapkan draf transaksi ini, cek lalu simpan:', drafts: [TxDraftSet([d])])
          : ChatMsg(
              user: false,
              text: 'AI belum aktif. Tanpa AI saya hanya bisa mencatat dari kalimat seperti "kopi 25rb pakai gopay". Aktifkan AI di Pengaturan > Asisten AI untuk tanya-jawab dan analisis.',
              error: true,
            );
    } else {
      try {
        final r = await ai!.ask(text);
        reply = ChatMsg(user: false, text: r.text.isEmpty ? 'Selesai.' : r.text, drafts: r.drafts);
      } on AiException catch (e) {
        reply = ChatMsg(user: false, text: e.message, error: true);
      } catch (_) {
        reply = ChatMsg(user: false, text: 'Terjadi kesalahan tak terduga. Coba lagi.', error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      msgs.add(reply);
      busy = false;
    });
    _toBottom();
    _saveChat();
  }

  Future<void> _scan() async {
    final s = AppScope.of(context);
    if (!s.aiKeySet) {
      final go = await confirmDialog(context, 'Scan struk membutuhkan AI. Atur kunci API sekarang?', ok: 'Atur', title: 'AI belum aktif');
      if (go && mounted) _openSettings();
      return;
    }
    if (!s.aiConsent) {
      final ok = await confirmDialog(
        context,
        'Foto struk akan dikirim ke ${s.aiProviderInfo.name} memakai kunci API Anda untuk dibaca. Lanjutkan?',
        ok: 'Setuju',
        title: 'Izin penggunaan data',
      );
      if (!ok || !mounted) return;
      await s.setAiConsent(true);
      if (!mounted) return;
    }
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Foto struk dengan kamera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    s.suppressLock = true;
    try {
      final x = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 80);
      if (x == null) {
        s.suppressLock = false;
        return;
      }
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      await _sendImage(bytes);
    } catch (_) {
      s.suppressLock = false;
      if (mounted) snack(context, 'Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.');
    }
  }

  Future<void> _sendImage(Uint8List bytes) async {
    if (busy) return;
    setState(() {
      msgs.add(ChatMsg(user: true, text: 'Foto struk', image: true));
      busy = true;
    });
    _toBottom();
    _saveChat();
    ChatMsg reply;
    try {
      final r = await ai!.ask(
        'Baca struk/nota pada foto ini lalu buat draf transaksi pengeluaran. Gunakan total yang dibayar dan tanggal pada struk jika terbaca.',
        image: bytes,
      );
      reply = ChatMsg(user: false, text: r.text.isEmpty ? 'Selesai.' : r.text, drafts: r.drafts);
    } on AiException catch (e) {
      reply = ChatMsg(user: false, text: e.message, error: true);
    } catch (_) {
      reply = ChatMsg(user: false, text: 'Terjadi kesalahan tak terduga. Coba lagi.', error: true);
    }
    if (!mounted) return;
    setState(() {
      msgs.add(reply);
      busy = false;
    });
    _toBottom();
    _saveChat();
  }

  Future<void> _prompt(String text) async {
    final s = AppScope.of(context);
    if (!s.aiKeySet) {
      final go = await confirmDialog(context, 'Fitur ini membutuhkan AI. Atur kunci API sekarang?', ok: 'Atur', title: 'AI belum aktif');
      if (go && mounted) _openSettings();
      return;
    }
    _send(text);
  }

  Future<void> _apply(Draft d) async {
    final s = AppScope.of(context);
    var n = 0;
    if (d is TxDraftSet) {
      n = await applyTxDrafts(s, d);
    } else if (d is CatDraft) {
      n = await applyCatDraft(s, d);
    } else if (d is BudgetDraft) {
      n = await applyBudgetDraft(s, d);
    }
    if (!mounted) return;
    setState(() => d.status = 'done');
    snack(context, '$n item disimpan');
  }

  void _copy(String t) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: t));
    snack(context, 'Pesan disalin');
  }

  void _fill(String t) {
    input.text = t;
    input.selection = TextSelection.collapsed(offset: t.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final h = DateTime.now().hour;
    final hello = h < 11 ? 'Selamat pagi' : (h < 15 ? 'Selamat siang' : (h < 18 ? 'Selamat sore' : 'Selamat malam'));

    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
            child: Row(children: [
              AiMark(size: 42, animate: busy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Asisten AI NACI', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: s.aiKeySet ? kIncome : kWarn, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.aiKeySet ? 'Aktif · ${s.aiLabel}' : 'Mode tanpa AI',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'new') {
                    ai?.reset();
                    AppScope.of(context).saveChat(null);
                    setState(msgs.clear);
                  } else {
                    _openSettings();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'new', child: Text('Percakapan baru')),
                  PopupMenuItem(value: 'settings', child: Text('Pengaturan AI')),
                ],
              ),
            ]),
          ),
          if (!s.aiKeySet && msgs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Color.alphaBlend(cs.primary.soft(.08), surfaceOf(context)),
                child: Row(children: [
                  AiSparkle(size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('AI belum aktif. Pencatatan cepat tetap bisa dipakai.', style: TextStyle(fontSize: 13))),
                  TextButton(onPressed: _openSettings, child: const Text('Atur')),
                ]),
              ),
            ),
          Expanded(
            child: msgs.isEmpty
                ? ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                    if (!s.aiKeySet)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          color: Color.alphaBlend(cs.primary.soft(.08), surfaceOf(context)),
                          child: Row(children: [
                            AiSparkle(size: 20, color: cs.primary),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('AI belum aktif. Pencatatan cepat tetap bisa dipakai.', style: TextStyle(fontSize: 13))),
                            TextButton(onPressed: _openSettings, child: const Text('Atur')),
                          ]),
                        ),
                      ),
                    FadeSlideIn(
                      child: Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.soft(.08),
                          ),
                          child: const Center(child: AiMark(size: 56)),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: Padding(padding: const EdgeInsets.only(top: 12), child: Text('$hello! Ada yang bisa dibantu?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      index: 2,
                      child: Text(
                        'Tulis kalimat biasa untuk mencatat, tanya kondisi keuangan, atau pilih salah satu ide di bawah.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - 10) / 2;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        for (var i = 0; i < _prompts.length; i++)
                          SizedBox(
                            width: w,
                            child: FadeSlideIn(
                              index: 3 + i,
                              child: AppCard(
                                margin: EdgeInsets.zero,
                                padding: const EdgeInsets.all(14),
                                onTap: () => _prompt(_prompts[i].$3),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  IconBadge(icon: _prompts[i].$1, color: cs.primary, size: 36),
                                  const SizedBox(height: 10),
                                  Text(
                                    _prompts[i].$2,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                      ]);
                    }),
                    const SizedBox(height: 20),
                    Text('Coba ketik', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final ex in const ['kopi 25rb', 'gaji 5jt masuk ke bank', 'bensin 50rb pakai gopay'])
                        ActionChip(label: Text(ex), onPressed: () => _fill(ex)),
                    ]),
                  ])
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: msgs.length + (busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == msgs.length) return _typing(context);
                      return _message(context, msgs[i], width);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
              decoration: BoxDecoration(
                color: surfaceOf(context),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: cs.outlineVariant.soft(dark ? .4 : .55)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  tooltip: 'Scan struk',
                  onPressed: busy ? null : _scan,
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: input,
                  builder: (context, v, _) {
                    final can = v.text.trim().isNotEmpty && !busy;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: can ? fillOf(context) : cs.onSurface.soft(.08),
                      ),
                      child: IconButton(
                        onPressed: can ? () => _send(input.text) : null,
                        icon: Icon(Icons.arrow_upward, color: can ? onFillOf(context) : cs.onSurfaceVariant),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _typing(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const AiMark(size: 28, animate: true),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: surfaceOf(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: cs.outlineVariant.soft(.5)),
          ),
          child: const _TypingDots(),
        ),
      ]),
    );
  }

  Widget _message(BuildContext context, ChatMsg m, double width) {
    final cs = Theme.of(context).colorScheme;
    final maxW = width * .78;
    if (m.user) {
      return FadeSlideIn(
        dy: 10,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onLongPress: () => _copy(m.text),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxW),
              margin: const EdgeInsets.only(bottom: 12, left: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: fillOf(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (m.image) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.receipt_long, size: 18, color: onFillOf(context))),
                Flexible(child: Text(m.text, style: TextStyle(color: onFillOf(context), height: 1.35))),
              ]),
            ),
          ),
        ),
      );
    }
    return FadeSlideIn(
      dy: 10,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: m.error ? IconBadge(icon: Icons.info_outline, color: cs.error, size: 28) : const AiMark(size: 28),
        ),
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW),
            margin: const EdgeInsets.only(bottom: 12, right: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.text.isNotEmpty)
                GestureDetector(
                  onLongPress: () => _copy(m.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      color: m.error ? cs.errorContainer.soft(.5) : surfaceOf(context),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: cs.outlineVariant.soft(.5)),
                    ),
                    child: MiniMarkdown(m.text),
                  ),
                ),
              for (final d in m.drafts)
                DraftCard(
                  draft: d,
                  onApply: () => _apply(d),
                  onDismiss: () => setState(() => d.status = 'dismissed'),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Tiga titik yang melompat bergantian saat asisten sedang berpikir.
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Builder(builder: (context) {
            final t = (_c.value + i * .18) % 1.0;
            final w = math.sin(t * math.pi);
            return Transform.translate(
              offset: Offset(0, -5 * w),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: cs.primary.soft(.4 + .5 * w), shape: BoxShape.circle),
              ),
            );
          }),
      ]),
    );
  }
}

// ======================= Markdown mini =======================

class MiniMarkdown extends StatelessWidget {
  const MiniMarkdown(this.text, {super.key});
  final String text;

  List<InlineSpan> _spans(String line, TextStyle base) {
    final parts = line.replaceAll('`', '').split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.copyWith(fontSize: 14.5, height: 1.4);
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      final t = line.trimLeft();
      if (t.isEmpty) {
        children.add(const SizedBox(height: 6));
      } else if (t.startsWith('#')) {
        final h = t.replaceFirst(RegExp(r'^#+\s*'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(TextSpan(children: _spans(h, base.copyWith(fontWeight: FontWeight.w700)))),
        ));
      } else if (RegExp(r'^[-*•]\s+').hasMatch(t)) {
        final body = t.replaceFirst(RegExp(r'^[-*•]\s+'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: base),
            Expanded(child: Text.rich(TextSpan(children: _spans(body, base)))),
          ]),
        ));
      } else if (RegExp(r'^\d+[.)]\s+').hasMatch(t)) {
        final m = RegExp(r'^(\d+[.)])\s+(.*)$').firstMatch(t)!;
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.group(1)}  ', style: base),
            Expanded(child: Text.rich(TextSpan(children: _spans(m.group(2)!, base)))),
          ]),
        ));
      } else {
        children.add(Text.rich(TextSpan(children: _spans(t, base))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

// ======================= Kartu draf =======================

class DraftCard extends StatelessWidget {
  const DraftCard({super.key, required this.draft, required this.onApply, required this.onDismiss});
  final Draft draft;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final d = draft;
    String title;
    String applyLabel;
    final rows = <Widget>[];

    if (d is TxDraftSet) {
      title = 'Draf transaksi (${d.items.length})';
      applyLabel = 'Simpan';
      for (final it in d.items) {
        final isT = it.type == TxType.transfer;
        final exp = it.type == TxType.expense;
        final c = isT ? null : (findCat(s, it.category, exp) ?? fallbackCat(s, exp));
        final w = findWallet(s, it.wallet) ?? (s.activeWallets.isNotEmpty ? s.activeWallets.first : null);
        final to = findWallet(s, it.toWallet);
        final color = isT ? kTransfer : Color(c?.color ?? 0xFF64748B);
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            IconBadge(icon: isT ? Icons.swap_horiz : kIcons[c?.icon ?? 20], color: color, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.note.isEmpty ? (isT ? 'Pindah dana' : (c?.name ?? 'Transaksi')) : it.note,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${isT ? '${w?.name ?? '?'} → ${to?.name ?? '?'}' : '${c?.name ?? '-'} · ${w?.name ?? '-'}'} · ${relDay(it.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            Text(
              '${it.type == TxType.income ? '+' : (exp ? '-' : '')}${rp(it.amount)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: it.type == TxType.income ? kIncome : (exp ? kExpense : kTransfer)),
            ),
          ]),
        ));
      }
    } else if (d is CatDraft) {
      title = 'Saran kategori (${d.items.length})';
      applyLabel = 'Terapkan';
      for (final it in d.items) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.arrow_forward, size: 14),
              label: Text(it.category, style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ));
      }
    } else if (d is BudgetDraft) {
      title = 'Saran anggaran (${d.items.length})';
      applyLabel = 'Terapkan';
      for (final it in d.items) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(it.category, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${rp(it.amount)} / bln', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ));
      }
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.soft(.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AiSparkle(size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        ]),
        const SizedBox(height: 4),
        ...rows,
        const SizedBox(height: 6),
        if (d.status == 'pending')
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: onDismiss, child: const Text('Abaikan')),
            const SizedBox(width: 4),
            FilledButton(onPressed: onApply, child: Text(applyLabel)),
          ])
        else
          Row(children: [
            Icon(d.status == 'done' ? Icons.check_circle : Icons.cancel_outlined, size: 18, color: d.status == 'done' ? kIncome : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(d.status == 'done' ? 'Tersimpan' : 'Diabaikan', style: Theme.of(context).textTheme.bodySmall),
          ]),
      ]),
    );
  }
}
