import 'package:flutter/material.dart';
import '../common.dart';
import '../services/native_bridge.dart';
import '../services/widget_sync.dart';
import 'paste_notif.dart';

/// Pengaturan deteksi otomatis transaksi dari notifikasi bank/e-wallet dan widget layar utama (Android).
class AutoCapturePage extends StatefulWidget {
  const AutoCapturePage({super.key});
  @override
  State<AutoCapturePage> createState() => _AutoCapturePageState();
}

class _AutoCapturePageState extends State<AutoCapturePage> with WidgetsBindingObserver {
  bool access = false;
  bool sms = false;
  int pending = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final a = await NativeBridge.notifAccessEnabled();
    final sm = await NativeBridge.smsEnabled();
    final p = await NativeBridge.pending();
    if (!mounted) return;
    setState(() {
      access = a;
      sms = sm;
      pending = p.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;

    if (!NativeBridge.supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deteksi Otomatis & Widget')),
        body: const EmptyState(
          icon: Icons.phone_android,
          title: 'Hanya tersedia di Android',
          subtitle: 'Pembaca notifikasi dan widget layar utama memakai fitur sistem Android.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Deteksi Otomatis & Widget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(icon: Icons.notifications_active_outlined, color: access ? kIncome : cs.primary, size: 42),
                const SizedBox(width: 12),
                const Expanded(child: Text('Catat dari notifikasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                SoftChip(text: access ? 'Aktif' : 'Mati', color: access ? kIncome : kWarn),
              ]),
              const SizedBox(height: 10),
              Text(
                'Saat bank atau e-wallet (GoPay, OVO, DANA, BCA, Mandiri, BRI, dll.) mengirim notifikasi transaksi, Tertata menyimpannya ke kotak masuk. Anda tinggal memeriksa dan mengonfirmasi, tanpa mengetik.',
                style: small,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: access
                    ? const OutlinedButton(onPressed: NativeBridge.openNotifSettings, child: Text('Kelola akses notifikasi'))
                    : const FilledButton(onPressed: NativeBridge.openNotifSettings, child: Text('Aktifkan akses notifikasi')),
              ),
              if (!access)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Di halaman yang terbuka, pilih Tertata lalu nyalakan. Jika Android menolak ("pengaturan terbatas"), buka Info aplikasi Tertata > menu titik tiga > Izinkan pengaturan terbatas, lalu ulangi.',
                    style: small,
                  ),
                ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sertakan SMS dari bank'),
                subtitle: const Text('Notifikasi aplikasi pesan juga disaring. Hanya yang memuat nominal Rp dan kata transaksi yang disimpan.'),
                value: sms,
                onChanged: access
                    ? (v) async {
                        await NativeBridge.setSms(v);
                        _load();
                      }
                    : null,
              ),
            ]),
          ),
          AppCard(
            onTap: pending == 0
                ? null
                : () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PasteNotifPage(fromInbox: true)));
                    _load();
                  },
            child: Row(children: [
              IconBadge(icon: Icons.inbox_outlined, color: cs.primary, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kotak masuk', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(pending == 0 ? 'Belum ada notifikasi menunggu' : '$pending notifikasi menunggu dicatat', style: small),
                ]),
              ),
              if (pending > 0) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                IconBadge(icon: Icons.widgets_outlined, color: kTransfer, size: 42),
                SizedBox(width: 12),
                Expanded(child: Text('Widget layar utama', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ]),
              const SizedBox(height: 10),
              Text('Tekan lama layar utama > Widget > Tertata, lalu letakkan. Isinya saldo, pengeluaran bulan ini, dan tombol "+ Catat" untuk mencatat cepat.', style: small),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan saldo di widget'),
                subtitle: const Text('Mati secara bawaan. Jika dinyalakan, saldo terlihat siapa saja yang melihat layar utama, tanpa PIN.'),
                value: WidgetSync.showBalance(s),
                onChanged: (v) async {
                  await s.setPrefBool(WidgetSync.prefKey, v);
                  WidgetSync.push(s, delay: Duration.zero);
                },
              ),
            ]),
          ),
          AppCard(
            color: cs.primary.soft(.05),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.lock_outline, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                const Text('Privasi', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Hanya notifikasi dari aplikasi bank/e-wallet yang dikenali (dan SMS bila Anda aktifkan) yang disimpan, dan hanya jika memuat nominal Rp dan kata transaksi. Notifikasi lain diabaikan dan tidak dibaca isinya. Semua tersimpan di perangkat ini, tidak dikirim ke mana pun (termasuk ke AI), dan dihapus otomatis setelah 14 hari. Anda bisa mencabut akses kapan saja di pengaturan Android.',
                style: small,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Banner di Beranda: muncul bila ada notifikasi transaksi yang menunggu dicatat.
class InboxBanner extends StatefulWidget {
  const InboxBanner({super.key});
  @override
  State<InboxBanner> createState() => _InboxBannerState();
}

class _InboxBannerState extends State<InboxBanner> with WidgetsBindingObserver {
  int n = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!NativeBridge.supported) return;
    final p = await NativeBridge.pending();
    if (mounted && p.length != n) setState(() => n = p.length);
  }

  @override
  Widget build(BuildContext context) {
    if (n == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      color: cs.primary.soft(.06),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PasteNotifPage(fromInbox: true)));
        _load();
      },
      child: Row(children: [
        IconBadge(icon: Icons.notifications_active_outlined, color: cs.primary, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n transaksi terdeteksi', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Dari notifikasi bank/e-wallet. Ketuk untuk memeriksa dan mencatat.', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ]),
    );
  }
}
