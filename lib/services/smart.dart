import '../common.dart';

// ======================= DRAF (menunggu konfirmasi pengguna) =======================

abstract class Draft {
  String status = 'pending'; // pending | done | dismissed
}

class TxDraft {
  TxDraft({
    required this.type,
    required this.amount,
    this.category,
    this.wallet,
    this.toWallet,
    DateTime? date,
    this.note = '',
  }) : date = date ?? DateTime.now();
  TxType type;
  double amount;
  String? category;
  String? wallet;
  String? toWallet;
  DateTime date;
  String note;
}

class TxDraftSet extends Draft {
  TxDraftSet(this.items);
  final List<TxDraft> items;
}

class CatAssign {
  CatAssign(this.txId, this.category, this.label);
  final String txId;
  final String category;
  final String label;
}

class CatDraft extends Draft {
  CatDraft(this.items);
  final List<CatAssign> items;
}

class BudgetItem {
  BudgetItem(this.category, this.amount);
  final String category;
  final double amount;
}

class BudgetDraft extends Draft {
  BudgetDraft(this.items);
  final List<BudgetItem> items;
}

// ======================= PENCARIAN NAMA =======================

Cat? findCat(AppState s, String? name, bool expense) {
  if (name == null || name.trim().isEmpty) return null;
  final pool = s.cats.where((c) => c.isExpense == expense).toList();
  final n = name.trim().toLowerCase();
  for (final c in pool) {
    if (c.name.toLowerCase() == n) return c;
  }
  for (final c in pool) {
    final cn = c.name.toLowerCase();
    if (cn.contains(n) || n.contains(cn)) return c;
  }
  return null;
}

Cat? fallbackCat(AppState s, bool expense) {
  final pool = s.cats.where((c) => c.isExpense == expense).toList();
  for (final c in pool) {
    if (c.name.toLowerCase() == 'lainnya') return c;
  }
  return pool.isEmpty ? null : pool.last;
}

Wallet? findWallet(AppState s, String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final n = name.trim().toLowerCase();
  final pool = s.activeWallets;
  for (final w in pool) {
    if (w.name.toLowerCase() == n) return w;
  }
  for (final w in pool) {
    final wn = w.name.toLowerCase();
    if (wn.contains(n) || n.contains(wn)) return w;
  }
  return null;
}

// ======================= KATEGORISASI LOKAL (tanpa AI) =======================

const Map<String, (List<String>, bool)> _keywords = {
  'Makanan': (['makan', 'nasi', 'ayam', 'warteg', 'resto', 'bakso', 'soto', 'mie', 'sate', 'lunch', 'dinner', 'sarapan', 'gofood', 'grabfood', 'shopeefood', 'padang', 'pecel', 'geprek', 'martabak'], true),
  'Kopi & Jajan': (['kopi', 'coffee', 'starbucks', 'kenangan', 'janji jiwa', 'boba', 'jajan', 'snack', 'cemilan', 'es teh', 'minum', 'roti', 'kue'], true),
  'Transportasi': (['gojek', 'grab', 'ojek', 'ojol', 'bus', 'krl', 'mrt', 'lrt', 'tol', 'parkir', 'kereta', 'taksi', 'taxi', 'angkot', 'transjakarta'], true),
  'BBM': (['bensin', 'pertamax', 'pertalite', 'solar', 'shell', 'bbm', 'spbu'], true),
  'Belanja': (['belanja', 'indomaret', 'alfamart', 'tokopedia', 'shopee', 'lazada', 'supermarket', 'baju', 'sepatu', 'blibli', 'tiktok shop'], true),
  'Tagihan': (['tagihan', 'cicilan', 'asuransi', 'bpjs', 'pajak', 'kredit', 'pinjaman', 'langganan', 'iuran'], true),
  'Listrik & Air': (['listrik', 'pln', 'pdam', 'token', 'galon', 'lpg'], true),
  'Pulsa & Internet': (['pulsa', 'paket data', 'kuota', 'internet', 'wifi', 'indihome', 'biznet', 'telkomsel', 'indosat'], true),
  'Hiburan': (['netflix', 'spotify', 'youtube', 'bioskop', 'film', 'game', 'steam', 'konser', 'nonton', 'disney', 'karaoke', 'playstation'], true),
  'Kesehatan': (['obat', 'dokter', 'apotek', 'klinik', 'rumah sakit', 'vitamin', 'dentist', 'periksa'], true),
  'Pendidikan': (['spp', 'kuliah', 'buku', 'kursus', 'sekolah', 'ukt', 'seminar', 'udemy', 'bimbel'], true),
  'Rumah': (['kos', 'kontrakan', 'sewa', 'kpr', 'perabot', 'renovasi', 'furnitur', 'ikea'], true),
  'Hadiah & Donasi': (['donasi', 'sedekah', 'zakat', 'infaq', 'hadiah', 'kado', 'sumbangan', 'amal'], true),
  'Gaji': (['gaji', 'salary', 'payroll'], false),
  'Bonus': (['bonus', 'thr', 'insentif', 'komisi'], false),
  'Usaha': (['jual', 'omzet', 'penjualan', 'dagang', 'profit'], false),
  'Investasi': (['dividen', 'saham', 'reksadana', 'bunga', 'crypto', 'emas', 'obligasi'], false),
};

final _splitter = RegExp(r'[^a-z0-9]+');

/// Menyarankan kategori dari catatan: belajar dari riwayat Anda, lalu kamus kata kunci.
Cat? suggestCategory(AppState s, String note, TxType type) {
  if (type == TxType.transfer) return null;
  final text = note.toLowerCase().trim();
  if (text.length < 3) return null;
  final expense = type == TxType.expense;
  final words = text.split(_splitter).where((w) => w.length >= 3).toSet();
  if (words.isEmpty) return null;

  final score = <String, int>{};
  for (final t in s.txs) {
    if (t.type != type || t.categoryId == null || t.note.isEmpty) continue;
    final tw = t.note.toLowerCase().split(_splitter).toSet();
    final hit = words.where(tw.contains).length;
    if (hit > 0) score[t.categoryId!] = (score[t.categoryId!] ?? 0) + hit;
  }
  if (score.isNotEmpty) {
    final best = score.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final c = s.cat(best.key);
    if (c != null) return c;
  }

  return keywordCat(s, text, expense);
}

// ======================= PARSER KALIMAT LOKAL (tanpa AI) =======================

final _amountRe = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(rb|ribu|k|jt|juta|m|miliar)?\b');

TxDraft? parseQuick(AppState s, String input) {
  final text = input.toLowerCase();
  double? best;
  String? bestRaw;
  var bestHasUnit = false;
  for (final m in _amountRe.allMatches(text)) {
    final numStr = m.group(1)!;
    final unit = m.group(2);
    double v;
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(numStr)) {
      v = double.parse(numStr.replaceAll(RegExp(r'[.,]'), ''));
    } else {
      v = double.tryParse(numStr.replaceAll(',', '.')) ?? 0;
    }
    final mult = switch (unit) {
      'rb' || 'ribu' || 'k' => 1e3,
      'jt' || 'juta' => 1e6,
      'm' || 'miliar' => 1e9,
      _ => 1.0,
    };
    v *= mult;
    final hasUnit = unit != null;
    if (!hasUnit && v < 100) continue;
    if (best == null || (hasUnit && !bestHasUnit) || (hasUnit == bestHasUnit && v > best)) {
      best = v;
      bestRaw = m.group(0);
      bestHasUnit = hasUnit;
    }
  }
  if (best == null || best <= 0) return null;

  const incomeWords = ['gaji', 'terima', 'dapat', 'bonus', 'masuk', 'jual', 'dividen', 'thr', 'komisi', 'cashback'];
  final isIncome = incomeWords.any(text.contains);
  final type = isIncome ? TxType.income : TxType.expense;

  String? walletName;
  for (final w in s.activeWallets) {
    if (text.contains(w.name.toLowerCase())) {
      walletName = w.name;
      break;
    }
  }
  if (walletName == null) {
    String? wantType;
    if (['gopay', 'ovo', 'dana', 'shopeepay', 'linkaja', 'ewallet', 'e-wallet'].any(text.contains)) {
      wantType = 'ewallet';
    } else if (['tunai', 'cash'].any(text.contains)) {
      wantType = 'cash';
    } else if (['debit', 'rekening', 'atm', 'transfer'].any(text.contains)) {
      wantType = 'bank';
    }
    if (wantType != null) {
      for (final w in s.activeWallets) {
        if (w.type == wantType) {
          walletName = w.name;
          break;
        }
      }
    }
  }

  var date = DateTime.now();
  if (text.contains('kemarin')) date = DateTime(date.year, date.month, date.day - 1);

  var note = input.replaceFirst(RegExp(RegExp.escape(bestRaw ?? ''), caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (note.isNotEmpty) note = note[0].toUpperCase() + note.substring(1);
  final cat = suggestCategory(s, note.isEmpty ? input : note, type);

  return TxDraft(type: type, amount: best, category: cat?.name, wallet: walletName, date: date, note: note);
}

// ======================= MENERAPKAN DRAF =======================

Future<int> applyTxDrafts(AppState s, TxDraftSet set) async {
  var n = 0;
  for (final d in set.items) {
    final isT = d.type == TxType.transfer;
    final w = findWallet(s, d.wallet) ?? (s.activeWallets.isNotEmpty ? s.activeWallets.first : null);
    if (w == null || d.amount <= 0) continue;
    Wallet? to;
    if (isT) {
      to = findWallet(s, d.toWallet);
      if (to == null || to.id == w.id) continue;
    }
    Cat? c;
    if (!isT) {
      final exp = d.type == TxType.expense;
      c = findCat(s, d.category, exp) ?? fallbackCat(s, exp);
    }
    final now = DateTime.now();
    final when = dayOnly(d.date) == dayOnly(now) ? now : DateTime(d.date.year, d.date.month, d.date.day, 12);
    await s.saveTx(Tx(
      id: s.uid(),
      type: d.type,
      amount: d.amount,
      walletId: w.id,
      toWalletId: to?.id,
      categoryId: c?.id,
      date: when,
      note: d.note,
    ));
    n++;
  }
  return n;
}

Future<int> applyCatDraft(AppState s, CatDraft d) async {
  var n = 0;
  for (final a in d.items) {
    final i = s.txs.indexWhere((t) => t.id == a.txId);
    if (i < 0) continue;
    final t = s.txs[i];
    final c = findCat(s, a.category, t.type == TxType.expense);
    if (c == null) continue;
    t.categoryId = c.id;
    await s.saveTx(t);
    n++;
  }
  return n;
}

Future<int> applyBudgetDraft(AppState s, BudgetDraft d) async {
  var n = 0;
  for (final it in d.items) {
    final c = findCat(s, it.category, true);
    if (c == null || it.amount <= 0) continue;
    final idx = s.budgets.indexWhere((b) => b.categoryId == c.id);
    await s.saveBudget(Budget(
      id: idx >= 0 ? s.budgets[idx].id : s.uid(),
      categoryId: c.id,
      amount: it.amount,
      rolloverFrom: idx >= 0 ? s.budgets[idx].rolloverFrom : null,
    ));
    n++;
  }
  return n;
}

Cat? keywordCat(AppState s, String text, bool expense) {
  for (final e in _keywords.entries) {
    if (e.value.$2 != expense) continue;
    if (e.value.$1.any((k) => text.contains(k))) {
      final c = findCat(s, e.key, expense);
      if (c != null) return c;
    }
  }
  return null;
}

/// Indeks kata -> kategori dari riwayat; cepat untuk kategorisasi massal (impor CSV).
class CategoryIndex {
  CategoryIndex(this.s) {
    for (final t in s.txs) {
      if (t.type == TxType.transfer || t.categoryId == null || t.note.isEmpty) continue;
      final m = t.type == TxType.expense ? _exp : _inc;
      for (final w in t.note.toLowerCase().split(_splitter).where((w) => w.length >= 3).toSet()) {
        final c = m.putIfAbsent(w, () => <String, int>{});
        c[t.categoryId!] = (c[t.categoryId!] ?? 0) + 1;
      }
    }
  }
  final AppState s;
  final _exp = <String, Map<String, int>>{};
  final _inc = <String, Map<String, int>>{};

  Cat? suggest(String note, TxType type) {
    if (type == TxType.transfer) return null;
    final text = note.toLowerCase().trim();
    if (text.length < 3) return null;
    final expense = type == TxType.expense;
    final m = expense ? _exp : _inc;
    final score = <String, int>{};
    for (final w in text.split(_splitter).where((w) => w.length >= 3).toSet()) {
      final c = m[w];
      if (c != null) c.forEach((k, v) => score[k] = (score[k] ?? 0) + v);
    }
    if (score.isNotEmpty) {
      final best = score.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final c = s.cat(best.key);
      if (c != null) return c;
    }
    return keywordCat(s, text, expense);
  }
}
