import 'package:flutter/material.dart';
import '../common.dart';
import '../core/founder_info.dart';
import '../services/open_url.dart';
import '../services/update_check.dart';
import 'auto_capture.dart';
import 'categories.dart';
import 'debts.dart';
import 'goals.dart';
import 'guide.dart';
import 'health.dart';
import 'import_csv.dart';
import 'paste_notif.dart';
import 'recurring.dart';
import 'settings.dart';
import 'subscriptions.dart';
import 'upcoming.dart';
import 'wallets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget item(IconData icon, Color color, String title, String sub, Widget page) => ListTile(
          leading: IconBadge(icon: icon, color: color, size: 40),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(page),
        );

    List<Widget> spaced(List<Widget> w) => [
          for (var i = 0; i < w.length; i++) ...[
            if (i > 0) const Divider(indent: 72, endIndent: 16),
            w[i],
          ],
        ];

    final activeRules = s.recurrings.where((r) => r.active).length;
    final openDebts = s.debts.where((d) => !d.settled).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const PageTitle('Lainnya', subtitle: 'Alat, pengaturan, dan data', padding: EdgeInsets.fromLTRB(4, 0, 4, 12)),
          AppCard(
            color: Theme.of(context).colorScheme.primary.soft(.06),
            child: Row(children: [
              Image.asset('assets/logo_mark.png', height: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tertata', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    '${s.txs.length} transaksi · ${s.activeWallets.length} dompet · ${s.cats.length} kategori',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ),
              if (s.aiKeySet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kIncome.soft(.14), borderRadius: BorderRadius.circular(20)),
                  child: const Text('AI aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kIncome)),
                ),
            ]),
          ),
          ValueListenableBuilder<UpdateInfo?>(
            valueListenable: UpdateCheck.available,
            builder: (context, u, _) => u == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppCard(
                      color: kIncome.soft(.10),
                      child: Row(children: [
                        const Icon(Icons.system_update_alt, color: kIncome),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Versi ${u.version} tersedia', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('Terpasang: $kAppVersion', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final ok = await openUrl(u.apkUrl ?? u.pageUrl);
                            if (!ok && context.mounted) snack(context, 'Tidak bisa membuka tautan');
                          },
                          child: const Text('Unduh'),
                        ),
                      ]),
                    ),
                  ),
          ),
          const SectionHeader('Kelola'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: spaced([
              item(Icons.favorite_outline, kIncome, 'Kesehatan Keuangan', 'Skor dan saran dari data Anda', const HealthPage()),
              item(Icons.content_paste_go_outlined, kTransfer, 'Tempel Notifikasi', 'Catat dari SMS/notifikasi bank & e-wallet', const PasteNotifPage()),
              item(Icons.notifications_active_outlined, kIncome, 'Deteksi Otomatis & Widget', 'Notifikasi bank dan widget layar utama', const AutoCapturePage()),
              item(Icons.event_note_outlined, kExpense, 'Akan Datang', 'Tagihan dan jatuh tempo 30 hari', const UpcomingPage()),
              item(Icons.account_balance_wallet_outlined, kTransfer, 'Dompet', '${s.activeWallets.length} dompet aktif', const WalletsPage()),
              item(Icons.category_outlined, const Color(0xFF8B5CF6), 'Kategori', '${s.cats.length} kategori', const CategoriesPage()),
              item(Icons.event_repeat, kIncome, 'Transaksi Berulang', '$activeRules aturan aktif', const RecurringPage()),
              item(Icons.autorenew, kWarn, 'Langganan', 'Tagihan rutin yang terdeteksi otomatis', const SubscriptionsPage()),
              item(Icons.handshake_outlined, kWarn, 'Hutang & Piutang', '$openDebts belum lunas', const DebtsPage()),
              item(Icons.upload_file_outlined, kTransfer, 'Impor Mutasi (CSV)', 'Dari rekening bank atau e-wallet', const ImportPage()),
              item(Icons.flag_outlined, const Color(0xFFEC4899), 'Target Tabungan', '${s.goals.length} target', const GoalsPage()),
            ])),
          ),
          const SectionHeader('Aplikasi'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: spaced([
              item(Icons.menu_book_outlined, kTransfer, 'Panduan', 'Cara memakai Tertata', const GuidePage()),
              item(Icons.settings_outlined, const Color(0xFF64748B), 'Pengaturan', 'Tema, keamanan, data & cadangan', const SettingsPage()),
            ])),
          ),
          const SizedBox(height: 20),
          const FounderInfo(),
        ],
      ),
    );
  }
}
