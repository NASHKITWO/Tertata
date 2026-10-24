import 'package:flutter/material.dart';
import '../common.dart';

Future<void> catDialog(BuildContext context, {Cat? c}) async {
  final s = AppScope.of(context);
  final name = TextEditingController(text: c?.name ?? '');
  var isExp = c?.isExpense ?? true;
  var color = c?.color ?? kColorValues[0];
  var icon = c?.icon ?? 20;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(c == null ? 'Kategori Baru' : 'Ubah Kategori'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (c == null)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Keluar')),
                  ButtonSegment(value: false, label: Text('Masuk')),
                ],
                selected: {isExp},
                onSelectionChanged: (v) => set(() => isExp = v.first),
              ),
            if (c == null) const SizedBox(height: 12),
            TextField(controller: name, decoration: fieldDeco(ctx, 'Nama kategori')),
            const SizedBox(height: 16),
            StylePicker(color: color, icon: icon, onColor: (v) => set(() => color = v), onIcon: (v) => set(() => icon = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              s.saveCat(Cat(id: c?.id ?? s.uid(), name: name.text.trim(), isExpense: isExp, color: color, icon: icon));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget list(bool exp) {
      final items = s.cats.where((c) => c.isExpense == exp).toList();
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final c in items)
              ListTile(
                leading: IconBadge(icon: kIcons[c.icon], color: Color(c.color), size: 40),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${s.txs.where((t) => t.categoryId == c.id).length} transaksi'),
                onTap: () => catDialog(context, c: c),
                trailing: IconButton(
                  tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Hapus kategori ${c.name}? Transaksinya menjadi "Tanpa kategori" dan anggarannya ikut terhapus.')) {
                      s.deleteCat(c.id);
                    }
                  },
                ),
              ),
          ]),
        ),
      ]);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori'),
          bottom: const TabBar(tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => catDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Kategori'),
        ),
        body: TabBarView(children: [list(true), list(false)]),
      ),
    );
  }
}
