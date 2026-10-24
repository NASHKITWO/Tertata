import 'package:flutter/material.dart';
import '../common.dart';

Future<void> walletDialog(BuildContext context, {Wallet? w}) async {
  final s = AppScope.of(context);
  final name = TextEditingController(text: w?.name ?? '');
  final init = TextEditingController(text: (w == null || w.initial == 0) ? '' : angka(w.initial));
  var type = w?.type ?? 'bank';
  var color = w?.color ?? kColorValues[5];
  var icon = w?.icon ?? kWalletTypeIcon[type]!;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(w == null ? 'Dompet Baru' : 'Ubah Dompet'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: fieldDeco(ctx, 'Nama dompet')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final e in kWalletTypes.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: type == e.key,
                  onSelected: (_) => set(() {
                    type = e.key;
                    icon = kWalletTypeIcon[e.key]!;
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: init,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahFormatter()],
              decoration: fieldDeco(ctx, 'Saldo awal', prefix: currencySymbol),
            ),
            const SizedBox(height: 16),
            StylePicker(color: color, icon: icon, onColor: (v) => set(() => color = v), onIcon: (v) => set(() => icon = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              s.saveWallet(Wallet(
                id: w?.id ?? s.uid(),
                name: name.text.trim(),
                type: type,
                initial: parseAmount(init.text),
                color: color,
                icon: icon,
                archived: w?.archived ?? false,
                sort: w?.sort ?? 0,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

Future<void> reconcileDialog(BuildContext context, Wallet w) async {
  final s = AppScope.of(context);
  final ctrl = TextEditingController();
  final current = s.balanceOf(w.id);
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final actual = ctrl.text.isEmpty ? null : parseAmount(ctrl.text);
        final diff = actual == null ? null : actual - current;
        return AlertDialog(
          title: Text('Cocokkan saldo ${w.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Saldo di aplikasi: ${rp(current)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahFormatter()],
              onChanged: (_) => set(() {}),
              decoration: fieldDeco(ctx, 'Saldo sebenarnya', prefix: currencySymbol, hint: 'cek di bank / e-wallet'),
            ),
            if (diff != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  diff == 0
                      ? 'Saldo sudah cocok.'
                      : 'Selisih ${diff > 0 ? '+' : '-'}${rp(diff.abs())}. Dicatat sebagai koreksi "Penyesuaian saldo" (tidak dihitung sebagai pemasukan/pengeluaran).',
                  style: TextStyle(color: diff == 0 ? kIncome : kWarn, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: (diff == null || diff == 0)
                  ? null
                  : () async {
                      await s.adjustBalance(w, actual!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('Catat penyesuaian'),
            ),
          ],
        );
      },
    ),
  );
}

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});

  Widget _tile(BuildContext context, AppState s, Wallet w) {
    return ListTile(
      leading: IconBadge(icon: kIcons[w.icon], color: Color(w.color), size: 44),
      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(kWalletTypes[w.type] ?? 'Dompet'),
      onTap: () => walletDialog(context, w: w),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(rp(s.balanceOf(w.id)), style: const TextStyle(fontWeight: FontWeight.w700)),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              walletDialog(context, w: w);
            } else if (v == 'reconcile') {
              reconcileDialog(context, w);
            } else if (v == 'archive') {
              s.toggleArchive(w);
            } else if (v == 'delete') {
              if (!await confirmDialog(context, 'Hapus dompet ${w.name}?')) return;
              final ok = await s.deleteWallet(w.id);
              if (!ok && context.mounted) {
                snack(context, 'Tidak bisa dihapus: masih dipakai transaksi/aturan berulang, atau dompet terakhir. Coba arsipkan.');
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Ubah')),
            const PopupMenuItem(value: 'reconcile', child: Text('Cocokkan saldo')),
            PopupMenuItem(value: 'archive', child: Text(w.archived ? 'Aktifkan kembali' : 'Arsipkan')),
            const PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final archived = s.wallets.where((w) => w.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
        onPressed: () => walletDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Dompet'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        AppCard(
          color: cs.primary.soft(.08),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total kekayaan bersih', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(rp(s.netWorth), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.primary)),
          ]),
        ),
        AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final w in s.activeWallets) _tile(context, s, w)])),
        if (archived.isNotEmpty) ...[
          const SectionHeader('Diarsipkan'),
          AppCard(padding: EdgeInsets.zero, child: Column(children: [for (final w in archived) _tile(context, s, w)])),
        ],
      ]),
    );
  }
}
