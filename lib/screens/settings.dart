import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../common.dart';
import '../services/auto_backup.dart';
import '../services/backup_crypto.dart';
import '../services/native_bridge.dart';
import '../services/reminders.dart';
import '../services/open_url.dart';
import '../services/security.dart';
import '../services/update_check.dart';
import 'ai_settings.dart';
import 'auto_backup_page.dart';
import 'crash_report.dart';
import '../core/founder_info.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // ---------- util ----------
  Future<T> _withBusy<T>(BuildContext context, Future<T> Function() job) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    try {
      return await job();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<String?> _askPassword(BuildContext context, String title, {String? info}) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (info != null) ...[Text(info), const SizedBox(height: 12)],
          TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: fieldDeco(ctx, 'Kata sandi')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Lanjut')),
        ],
      ),
    );
    return r;
  }

  Future<void> _share(BuildContext context, AppState s, String name, String content, String mime) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(content);
    s.suppressLock = true;
    await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: name);
  }


  // ---------- pembaruan ----------
  Future<void> _showUpdate(BuildContext context, UpdateInfo u) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Versi ${u.version} tersedia'),
        content: SingleChildScrollView(child: Text(u.notes.isEmpty ? 'Versi terbaru Tertata sudah terbit.' : u.notes)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(u.apkUrl != null ? 'Unduh' : 'Buka halaman')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      final ok = await openUrl(u.apkUrl ?? u.pageUrl);
      if (!ok && context.mounted) snack(context, 'Tidak bisa membuka tautan');
    }
  }

  Future<void> _checkUpdate(BuildContext context, AppState s) async {
    try {
      final info = await _withBusy(context, () => UpdateCheck.checkNow(s.prefs));
      if (!context.mounted) return;
      if (info == null) {
        snack(context, 'Anda sudah memakai versi terbaru ($kAppVersion)');
      } else {
        await _showUpdate(context, info);
      }
    } catch (_) {
      if (context.mounted) snack(context, 'Gagal memeriksa. Periksa koneksi internet lalu coba lagi.');
    }
  }

  // ---------- data ----------
  Future<void> _backup(BuildContext context, AppState s, String stamp) async {
    final pw = await _askPassword(
      context,
      'Cadangkan data',
      info: 'Isi kata sandi agar file cadangan terenkripsi (disarankan). Kosongkan untuk file biasa. Kata sandi tidak bisa dipulihkan jika lupa.',
    );
    if (pw == null || !context.mounted) return;
    if (pw.isNotEmpty) {
      final problem = backupPasswordProblem(pw);
      if (problem != null) {
        snack(context, problem);
        return;
      }
    }
    final raw = pw.isEmpty ? await s.exportBackup() : await _withBusy(context, () => s.exportBackup(password: pw));
    if (!context.mounted) return;
    await _share(context, s, 'catatan_uang_backup_$stamp${pw.isEmpty ? '' : '_terenkripsi'}.json', raw, 'application/json');
    await s.markBackup();
  }

  Future<void> _restore(BuildContext context, AppState s) async {
    s.suppressLock = true;
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r == null || r.files.single.path == null) {
      s.suppressLock = false;
      return;
    }
    String raw;
    try {
      raw = await File(r.files.single.path!).readAsString();
    } catch (_) {
      if (context.mounted) snack(context, 'Gagal membaca file');
      return;
    }
    if (!context.mounted) return;
    if (isEncryptedBackup(raw)) {
      final pw = await _askPassword(context, 'Kata sandi cadangan');
      if (pw == null || !context.mounted) return;
      try {
        final encrypted = raw;
        raw = await _withBusy(context, () => decryptBackup(encrypted, pw));
      } on BackupException catch (e) {
        if (context.mounted) snack(context, e.message);
        return;
      }
    }
    if (!context.mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan data'),
        content: const Text(
          'Ganti semua: data saat ini dihapus lalu diganti isi cadangan.\n\nGabungkan: hanya menambah data yang belum ada (cocok untuk cadangan dari aplikasi ini sendiri).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Gabungkan')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Ganti semua')),
        ],
      ),
    );
    if (mode == null) return;
    try {
      await s.importBackup(raw, merge: mode == 'merge');
      if (context.mounted) snack(context, 'Data berhasil dipulihkan');
    } catch (_) {
      if (context.mounted) snack(context, 'File cadangan tidak valid');
    }
  }

  // ---------- pengingat ----------
  Future<void> _toggleReminder(BuildContext context, AppState s, String key, bool v) async {
    if (v) {
      final ok = await Reminders.requestPermission();
      if (!ok) {
        if (context.mounted) snack(context, 'Izin notifikasi tidak diberikan. Aktifkan di pengaturan sistem.');
        return;
      }
    }
    await s.setPrefBool(key, v);
    await Reminders.schedule(s);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);

    Future<void> changePin() async {
      if (await verifyPinScreen(context) && context.mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const AiMark(size: 40),
            title: const Text('Asisten AI', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(s.aiKeySet ? 'Aktif · ${s.aiLabel}' : 'Belum diatur'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsPage())),
          ),
        ),
        const SectionHeader('Tampilan'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', label: Text('Sistem')),
                ButtonSegment(value: 'light', label: Text('Terang')),
                ButtonSegment(value: 'dark', label: Text('Gelap')),
              ],
              selected: {s.themeKey},
              onSelectionChanged: (v) => s.setTheme(v.first),
            ),
            const SizedBox(height: 16),
            const Text('Warna aksen', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < kAccents.length; i++)
                GestureDetector(
                  onTap: () => s.setAccent(i),
                  child: Tooltip(
                    message: kAccentNames[i],
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: kAccents[i],
                      child: s.accentIndex == i ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            const Text('Simbol mata uang', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final c in kCurrencies) ChoiceChip(label: Text(c.trim()), selected: s.currency == c, onSelected: (_) => s.setCurrency(c)),
            ]),
          ]),
        ),
        const SectionHeader('Keamanan'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              secondary: const IconBadge(icon: Icons.lock_outline, color: kTransfer, size: 40),
              title: const Text('Kunci aplikasi dengan PIN', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('PIN 6 digit, disimpan sebagai hash di perangkat'),
              value: s.pinEnabled,
              onChanged: (v) async {
                if (v) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
                } else if (await verifyPinScreen(context)) {
                  await s.clearPin();
                }
              },
            ),
            if (NativeBridge.supported)
              SwitchListTile(
                secondary: const IconBadge(icon: Icons.visibility_off_outlined, color: kWarn, size: 40),
                title: const Text('Blokir tangkapan layar', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Layar tidak bisa difoto/direkam dan tampil kosong di aplikasi terbaru'),
                value: s.prefs.getBool('secure_screen') ?? false,
                onChanged: (v) async {
                  await NativeBridge.setSecure(v);
                  await s.setPrefBool('secure_screen', v);
                },
              ),
            SwitchListTile(
              secondary: const IconBadge(icon: Icons.fingerprint, color: kIncome, size: 40),
              title: const Text('Buka dengan biometrik', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.pinEnabled ? 'Sidik jari / wajah. PIN tetap jadi cadangan' : 'Aktifkan kunci PIN dulu'),
              value: s.pinEnabled && s.biometricOn,
              onChanged: !s.pinEnabled
                  ? null
                  : (v) async {
                      if (!v) {
                        await s.setPrefBool('bio', false);
                        return;
                      }
                      if (!await biometricAvailable()) {
                        if (context.mounted) snack(context, 'Biometrik tidak tersedia atau belum didaftarkan di perangkat ini');
                        return;
                      }
                      if (await biometricAuthSafe(s)) await s.setPrefBool('bio', true);
                    },
            ),
            if (s.pinEnabled) ...[
              if (s.pinIsLegacy)
                ListTile(
                  leading: const IconBadge(icon: Icons.shield_outlined, color: kWarn, size: 40),
                  title: const Text('Perkuat PIN menjadi 6 digit', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('PIN Anda saat ini ${s.pinLength} digit'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: changePin,
                ),
              ListTile(
                leading: const IconBadge(icon: Icons.password, color: kWarn, size: 40),
                title: const Text('Ganti PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('PIN baru 6 digit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: changePin,
              ),
              ListTile(
                leading: const IconBadge(icon: Icons.timer_outlined, color: kIncome, size: 40),
                title: const Text('Kunci otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: DropdownButton<int>(
                  value: s.autoLockSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Segera')),
                    DropdownMenuItem(value: 30, child: Text('30 detik')),
                    DropdownMenuItem(value: 60, child: Text('1 menit')),
                    DropdownMenuItem(value: 300, child: Text('5 menit')),
                  ],
                  onChanged: (v) => s.setAutoLock(v ?? 30),
                ),
              ),
            ],
          ]),
        ),
        const SectionHeader('Pengingat'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              secondary: const IconBadge(icon: Icons.event_available_outlined, color: kWarn, size: 40),
              title: const Text('Tagihan & jatuh tempo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Transaksi berulang, hutang, dan piutang (H-1 dan hari-H, pukul 09.00)'),
              value: s.remindersOn,
              onChanged: (v) => _toggleReminder(context, s, 'rem_bills', v),
            ),
            SwitchListTile(
              secondary: const IconBadge(icon: Icons.edit_calendar_outlined, color: kTransfer, size: 40),
              title: const Text('Pengingat catat harian', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Setiap hari pukul ${time.format(context)}'),
              value: s.dailyReminder,
              onChanged: (v) => _toggleReminder(context, s, 'rem_daily', v),
            ),
            if (s.dailyReminder)
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text('Ubah jam pengingat'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: time);
                  if (t != null) {
                    await s.setPrefInt('rem_hour', t.hour);
                    await s.setPrefInt('rem_min', t.minute);
                    await Reminders.schedule(s);
                  }
                },
              ),
          ]),
        ),
        const SectionHeader('Data'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const IconBadge(icon: Icons.table_view_outlined, color: kIncome, size: 40),
              title: const Text('Ekspor transaksi (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Bisa dibuka di Excel / Google Sheets'),
              onTap: () => _share(context, s, 'transaksi_$stamp.csv', s.exportCsv(), 'text/csv'),
            ),
            ListTile(
              leading: const IconBadge(icon: Icons.backup_outlined, color: kTransfer, size: 40),
              title: const Text('Cadangkan data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.lastBackup == null ? 'File JSON, bisa dienkripsi dengan kata sandi' : 'Terakhir: ${tgl(s.lastBackup!)}'),
              onTap: () => _backup(context, s, stamp),
            ),
            ListTile(
              leading: const IconBadge(icon: Icons.schedule_outlined, color: kIncome, size: 40),
              title: const Text('Cadangan otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(AutoBackup.isEnabled(s.prefs) ? 'Menyala · setiap ${AutoBackup.days(s.prefs)} hari' : 'Mati · terenkripsi, disimpan di HP'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoBackupPage())),
            ),
            ListTile(
              leading: const IconBadge(icon: Icons.restore_outlined, color: kWarn, size: 40),
              title: const Text('Pulihkan data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ganti semua atau gabungkan'),
              onTap: () => _restore(context, s),
            ),
            ListTile(
              leading: const IconBadge(icon: Icons.delete_forever_outlined, color: kDanger, size: 40),
              title: const Text('Hapus semua data', style: TextStyle(fontWeight: FontWeight.w600, color: kDanger)),
              onTap: () async {
                if (await confirmDialog(context, 'Semua transaksi, anggaran, target, dan hutang akan dihapus permanen. Disarankan membuat cadangan dulu.',
                    ok: 'Hapus semua')) {
                  await s.resetAll();
                  if (context.mounted) snack(context, 'Semua data dihapus');
                }
              },
            ),
          ]),
        ),
        const SectionHeader('Pembaruan & masalah'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const IconBadge(icon: Icons.system_update_alt, color: kTransfer, size: 40),
              title: const Text('Periksa pembaruan', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Versi terpasang $kAppVersion'),
              onTap: () => _checkUpdate(context, s),
            ),
            SwitchListTile(
              secondary: const SizedBox(width: 40),
              title: const Text('Periksa otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Sekali sehari, ke GitHub. Tanpa mengirim data Anda.'),
              value: s.prefs.getBool(UpdateCheck.autoKey) ?? true,
              onChanged: (v) => s.setPrefBool(UpdateCheck.autoKey, v),
            ),
            ListTile(
              leading: const IconBadge(icon: Icons.bug_report_outlined, color: kWarn, size: 40),
              title: const Text('Laporan masalah', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Error yang tercatat di perangkat ini'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrashReportPage())),
            ),
          ]),
        ),
        const SectionHeader('Tentang'),
        AppCard(
          child: Column(children: [
            const BrandLogo(height: 110),
            const SizedBox(height: 8),
            Text(
              'Tertata v$kAppVersion\nAplikasi ini hanya mencatat dan mengelola keuangan; tidak membayar atau memindahkan uang sungguhan. Data tersimpan lokal (SQLite) di perangkat Anda.',
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Kebijakan privasi', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Kebijakan privasi'),
                content: const SingleChildScrollView(child: Text(_privacyText)),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const FounderInfo(),
      ]),
    );
  }
}

const _privacyText = 'Data keuangan Anda (transaksi, dompet, anggaran, target, hutang) disimpan lokal di perangkat. '
    'Kami tidak punya server, akun, iklan, atau analitik, sehingga kami tidak menerima data Anda.\n\n'
    'Fitur AI dan scan struk bersifat opsional dan baru aktif setelah Anda memasukkan kunci API milik sendiri dari penyedia AI '
    'pilihan Anda (mis. Google Gemini, Groq, OpenRouter) dan menyetujuinya. Saat dipakai, pertanyaan Anda, transaksi yang relevan, dan foto struk dikirim langsung dari '
    'perangkat ke penyedia tersebut dan diproses menurut kebijakannya; paket gratis umumnya boleh memakai data untuk peningkatan produk. Kunci API disimpan terenkripsi dan tidak '
    'ikut cadangan. Anda bisa mencabut persetujuan kapan saja di Pengaturan AI.\n\n'
    'Aplikasi memeriksa versi terbaru ke api.github.com paling sering sekali sehari tanpa mengirim data pribadi (GitHub tetap melihat alamat IP); bisa dimatikan di Pengaturan. '
    'Error aplikasi dicatat hanya di perangkat dan tidak dikirim kecuali Anda membagikannya sendiri.\n\n'
    'Hapus semua data atau Lupa PIN menghapus data di perangkat. Versi lengkap: berkas PRIVACY.md di repositori GitHub Tertata.';
