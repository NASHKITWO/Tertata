import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../common.dart';
import '../services/auto_backup.dart';
import '../services/backup_crypto.dart';
import '../services/crash_log.dart';

class AutoBackupPage extends StatefulWidget {
  const AutoBackupPage({super.key});

  @override
  State<AutoBackupPage> createState() => _AutoBackupPageState();
}

class _AutoBackupPageState extends State<AutoBackupPage> {
  List<File> _files = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    List<File> f = [];
    try {
      f = await AutoBackup.files();
    } catch (_) {
      // Penyimpanan tidak tersedia: tampilkan daftar kosong.
    }
    if (mounted) setState(() => _files = f);
  }

  Future<String?> _askNewPassword() async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Kata sandi cadangan'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Kata sandi ini mengunci semua cadangan otomatis dan disimpan terenkripsi di HP agar cadangan bisa dibuat tanpa ditanya. '
              'Catat baik-baik: tanpa kata sandi ini cadangan tidak bisa dibuka, termasuk di HP baru.',
            ),
            const SizedBox(height: 12),
            TextField(controller: a, obscureText: true, autofocus: true, decoration: fieldDeco(ctx, 'Kata sandi')),
            const SizedBox(height: 8),
            TextField(controller: b, obscureText: true, decoration: fieldDeco(ctx, 'Ulangi kata sandi')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: kDanger))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final problem = backupPasswordProblem(a.text);
                if (problem != null) {
                  setD(() => error = problem);
                } else if (a.text != b.text) {
                  setD(() => error = 'Kedua kata sandi tidak sama.');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: const Text('Nyalakan'),
            ),
          ],
        ),
      ),
    );
    return r;
  }

  Future<void> _toggle(AppState s, bool on) async {
    if (on) {
      final pw = await _askNewPassword();
      if (pw == null || !mounted) return;
      setState(() => _busy = true);
      try {
        await AutoBackup.enable(s.prefs, pw, (p) => s.exportBackup(password: p), everyDays: AutoBackup.days(s.prefs));
        if (mounted) snack(context, 'Cadangan otomatis menyala. Cadangan pertama sudah dibuat.');
      } catch (e, st) {
        await CrashLog.record(e, st);
        if (mounted) snack(context, 'Gagal menyalakan cadangan otomatis');
      }
    } else {
      final del = await confirmDialog(
        context,
        'Cadangan otomatis dimatikan dan kata sandi tersimpan dihapus. Hapus juga file cadangan yang sudah ada di HP?',
        ok: 'Hapus file',
        title: 'Matikan',
      );
      await AutoBackup.disable(s.prefs, deleteFiles: del);
    }
    s.refresh();
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _runNow(AppState s) async {
    setState(() => _busy = true);
    try {
      await AutoBackup.runNow(s.prefs, (p) => s.exportBackup(password: p));
      if (mounted) snack(context, 'Cadangan dibuat');
    } catch (e, st) {
      await CrashLog.record(e, st);
      if (mounted) snack(context, 'Gagal membuat cadangan');
    }
    s.refresh();
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askPassword() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kata sandi cadangan'),
        content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: fieldDeco(ctx, 'Kata sandi')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Lanjut')),
        ],
      ),
    );
  }

  Future<void> _restore(AppState s, File f) async {
    String raw;
    try {
      raw = await f.readAsString();
    } catch (_) {
      if (mounted) snack(context, 'Gagal membaca cadangan');
      return;
    }
    if (isEncryptedBackup(raw)) {
      var pw = await AutoBackup.storedPassword();
      if (pw == null || pw.isEmpty) {
        pw = await _askPassword();
        if (pw == null || !mounted) return;
      }
      try {
        final enc = raw;
        final key = pw;
        raw = await decryptBackup(enc, key);
      } on BackupException {
        // Kata sandi tersimpan mungkin sudah berbeda dari yang dipakai berkas ini: tanyakan sekali.
        final manual = await _askPassword();
        if (manual == null || !mounted) return;
        try {
          raw = await decryptBackup(await f.readAsString(), manual);
        } on BackupException catch (e) {
          if (mounted) snack(context, e.message);
          return;
        }
      }
    }
    if (!mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan data'),
        content: const Text(
          'Ganti semua: data saat ini dihapus lalu diganti isi cadangan.\n\nGabungkan: hanya menambah data yang belum ada.',
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
      if (mounted) snack(context, 'Data berhasil dipulihkan');
    } catch (_) {
      if (mounted) snack(context, 'File cadangan tidak valid');
    }
  }

  Future<void> _share(AppState s, File f) async {
    s.suppressLock = true;
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')], subject: f.uri.pathSegments.last);
  }

  String _size(File f) {
    final kb = f.lengthSync() / 1024;
    return kb < 1024 ? '${kb.toStringAsFixed(0)} KB' : '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final on = AutoBackup.isEnabled(s.prefs);
    final last = AutoBackup.last(s.prefs);
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangan otomatis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          AppCard(
            child: Text(
              'Membuat cadangan terenkripsi secara berkala dan menyimpannya di HP (${AutoBackup.keep} terbaru). '
              'Berjalan saat aplikasi dibuka, bukan di latar belakang. '
              'Cadangan ikut hilang bila aplikasi dicopot atau HP rusak, jadi bagikan berkasnya ke Google Drive atau tempat lain secara berkala.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SwitchListTile(
                title: const Text('Cadangan otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(on ? (last == null ? 'Menyala' : 'Terakhir: ${tgl(last)}') : 'Mati'),
                value: on,
                onChanged: _busy ? null : (v) => _toggle(s, v),
              ),
              if (on) ...[
                const Divider(height: 1),
                ListTile(
                  title: const Text('Seberapa sering'),
                  trailing: DropdownButton<int>(
                    value: AutoBackup.days(s.prefs),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final d in AutoBackup.dayChoices) DropdownMenuItem(value: d, child: Text(d == 1 ? 'Setiap hari' : 'Setiap $d hari')),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) async {
                            if (v == null) return;
                            await s.setPrefInt(AutoBackup.daysKey, v);
                            if (mounted) setState(() {});
                          },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.backup_outlined),
                  title: const Text('Cadangkan sekarang'),
                  onTap: _busy ? null : () => _runNow(s),
                ),
              ],
            ]),
          ),
          if (_files.isNotEmpty) ...[
            const SectionHeader('Cadangan di HP ini'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final f in _files)
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(_label(f)),
                    subtitle: Text(_size(f)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.restore_outlined), tooltip: 'Pulihkan', onPressed: () => _restore(s, f)),
                      IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Bagikan', onPressed: () => _share(s, f)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              'Ketuk ikon pulihkan untuk memakai cadangan itu langsung. Berkas yang Anda simpan di luar HP dipulihkan lewat Pengaturan > Pulihkan data.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _label(File f) {
    final m = RegExp(r'tertata_auto_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})').firstMatch(f.uri.pathSegments.last);
    if (m == null) return f.uri.pathSegments.last;
    return tgl(DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!))) + ' · ${m.group(4)}:${m.group(5)}';
  }
}
