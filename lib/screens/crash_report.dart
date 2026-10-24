import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../common.dart';
import '../core/founder_info.dart';
import '../services/crash_log.dart';

/// Daftar error yang tercatat di perangkat. Tidak ada yang dikirim otomatis.
class CrashReportPage extends StatefulWidget {
  const CrashReportPage({super.key});

  @override
  State<CrashReportPage> createState() => _CrashReportPageState();
}

class _CrashReportPageState extends State<CrashReportPage> {
  String get _text => CrashLog.report(CrashLog.entries, platform: CrashLog.platformName);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final items = CrashLog.entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan masalah')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          AppCard(
            child: Text(
              'Bila aplikasi bermasalah, errornya dicatat di sini, hanya di perangkat Anda. '
              'Tidak ada yang dikirim otomatis. Catatan tidak memuat transaksi atau saldo, dan angka panjang disamarkan. '
              'Anda yang memutuskan apakah mau membagikannya ke developer (${FounderInfo.email}).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Belum ada masalah tercatat.'))))
          else ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Bagikan laporan'),
                  onPressed: () async {
                    s.suppressLock = true;
                    await Share.share(_text, subject: 'Laporan masalah Tertata');
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _text));
                  snack(context, 'Laporan disalin');
                },
              ),
            ]),
            const SizedBox(height: 12),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.time.toLocal().toString().substring(0, 16), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(e.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: kDanger),
              label: const Text('Hapus semua catatan', style: TextStyle(color: kDanger)),
              onPressed: () async {
                if (await confirmDialog(context, 'Semua catatan masalah di perangkat ini akan dihapus.', ok: 'Hapus')) {
                  await CrashLog.clear();
                  if (mounted) setState(() {});
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
