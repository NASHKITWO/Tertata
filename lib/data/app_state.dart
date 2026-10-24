import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as c;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/ai_providers.dart';
import '../services/auto_backup.dart';
import '../services/backup_crypto.dart';
import 'db.dart';
import 'models.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class PinAttempt {
  const PinAttempt({this.ok = false, this.locked = false, this.triesLeft = 0});
  final bool ok;
  final bool locked;
  final int triesLeft;
}

class AppState extends ChangeNotifier {
  AppState(this.db, this.prefs);
  final Db db;
  final SharedPreferences prefs;

  List<Wallet> wallets = [];
  List<Cat> cats = [];
  List<Tx> txs = [];
  List<Budget> budgets = [];
  List<Goal> goals = [];
  List<Recurring> recurrings = [];
  List<Debt> debts = [];
  final Map<String, double> _bal = {};
  final Map<String, double> _sumCache = {};
  final Map<String, Map<String?, double>> _catCache = {};
  int? _streak;

  /// true sebelum membuka file picker / share sheet agar app tidak terkunci saat kembali.
  bool suppressLock = false;
  int _n = 0;

  String uid() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_n++).toRadixString(36)}';

  // ====================== PENGATURAN ======================
  ThemeMode get themeMode => switch (prefs.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  String get themeKey => prefs.getString('theme') ?? 'system';
  int get accentIndex => (prefs.getInt('accent') ?? 0).clamp(0, kAccents.length - 1).toInt();
  Color get accent => kAccents[accentIndex];
  String get currency => prefs.getString('currency') ?? 'Rp ';
  bool get hideBalance => prefs.getBool('hide') ?? false;
  bool get pinEnabled => _pinHash != null || prefs.getString('pin_hash') != null || (prefs.getBool('pin_on') ?? false);
  int get pinLength => prefs.getInt('pin_len') ?? 6;
  /// true jika PIN tersimpan masih 4 digit (dibuat sebelum v5.3).
  bool get pinIsLegacy => pinEnabled && pinLength != 6;
  int get autoLockSeconds => prefs.getInt('autolock') ?? 30;

  Future<void> setTheme(String v) async {
    await prefs.setString('theme', v);
    notifyListeners();
  }

  Future<void> setAccent(int i) async {
    await prefs.setInt('accent', i);
    notifyListeners();
  }

  Future<void> setCurrency(String c) async {
    currencySymbol = c;
    await prefs.setString('currency', c);
    notifyListeners();
  }

  Future<void> setHide(bool v) async {
    await prefs.setBool('hide', v);
    notifyListeners();
  }

  Future<void> setAutoLock(int sec) async {
    await prefs.setInt('autolock', sec);
    notifyListeners();
  }

  // ====================== PIN ======================
  // PIN disimpan sebagai hash PBKDF2-SHA256 + salt acak di penyimpanan aman (Keystore),
  // bukan SharedPreferences. Hitungan salah dan sisa waktu kunci juga di sana, dan
  // sisa waktu dihitung dengan stopwatch (monoton), bukan jam dinding, sehingga mengubah
  // jam HP atau menutup aplikasi tidak memperpendek kunci.
  static const _pinIterations = 100000;
  static const _lockSteps = [30, 60, 120, 300];
  static const _maxFails = 5;
  String? _pinHash;
  String? _pinSalt;
  int _pinIter = _pinIterations;
  int _pinFails = 0;
  int _pinLockLevel = 0;
  int _lockBaseMs = 0;
  final Stopwatch _lockSw = Stopwatch();

  Future<void> loadPin() async {
    _pinHash = null;
    _pinSalt = null;
    try {
      final raw = await _secure.read(key: 'pin_v2');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _pinHash = j['h'] as String;
        _pinSalt = j['s'] as String;
        _pinIter = (j['i'] as int?) ?? _pinIterations;
      }
      final lk = await _secure.read(key: 'pin_lock');
      if (lk != null) {
        final j = jsonDecode(lk) as Map<String, dynamic>;
        _pinFails = (j['f'] as int?) ?? 0;
        _pinLockLevel = (j['v'] as int?) ?? 0;
        _lockBaseMs = (j['ms'] as int?) ?? 0;
        _lockSw
          ..reset()
          ..start();
      }
    } catch (_) {
      // Penyimpanan aman gagal dibaca: PIN tetap dianggap aktif (lihat pin_on) dan
      // verifikasi gagal, jadi kunci tidak terbuka diam-diam.
    }
  }

  static Future<String> _derive(String pin, String salt, int iterations) {
    return Isolate.run(() async {
      final kdf = c.Pbkdf2(macAlgorithm: c.Hmac.sha256(), iterations: iterations, bits: 256);
      final key = await kdf.deriveKeyFromPassword(password: pin, nonce: utf8.encode(salt));
      return base64Encode(await key.extractBytes());
    });
  }

  static bool _constEq(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return d == 0;
  }

  String _legacyHash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Mengembalikan false jika penyimpanan aman gagal; PIN tidak diaktifkan dalam kasus itu.
  Future<bool> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final hash = await _derive(pin, salt, _pinIterations);
    try {
      await _secure.write(key: 'pin_v2', value: jsonEncode({'h': hash, 's': salt, 'i': _pinIterations}));
    } catch (_) {
      return false;
    }
    _pinHash = hash;
    _pinSalt = salt;
    _pinIter = _pinIterations;
    await prefs.setBool('pin_on', true);
    await prefs.setInt('pin_len', pin.length);
    for (final k in const ['pin_hash', 'pin_salt', 'pin_fails', 'pin_lock_level', 'pin_lock_until']) {
      await prefs.remove(k);
    }
    await _resetLock();
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final legacy = prefs.getString('pin_hash');
    if (_pinHash == null && legacy != null) {
      // PIN lama (SHA-256 di SharedPreferences): terima sekali, lalu pindahkan ke format baru.
      final ok = _constEq(_legacyHash(prefs.getString('pin_salt') ?? '', pin), legacy);
      if (ok) await setPin(pin);
      return ok;
    }
    if (_pinHash == null || _pinSalt == null) return false;
    return _constEq(await _derive(pin, _pinSalt!, _pinIter), _pinHash!);
  }

  /// Sisa detik kunci sementara (0 jika tidak terkunci).
  int get pinLockLeft {
    final ms = _lockBaseMs - _lockSw.elapsedMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Satu percobaan PIN lengkap: hitungan salah disimpan SEBELUM PIN diperiksa,
  /// agar menutup paksa aplikasi di tengah pemeriksaan tidak menghapus percobaan.
  Future<PinAttempt> attemptPin(String pin) async {
    if (pinLockLeft > 0) return const PinAttempt(locked: true);
    _pinFails++;
    await persistPinLock();
    if (await verifyPin(pin)) {
      await _resetLock();
      return const PinAttempt(ok: true);
    }
    if (_pinFails >= _maxFails) {
      final secs = _lockSteps[_pinLockLevel.clamp(0, _lockSteps.length - 1).toInt()];
      _pinFails = 0;
      _pinLockLevel++;
      _lockBaseMs = secs * 1000;
      _lockSw
        ..reset()
        ..start();
      await persistPinLock();
      return const PinAttempt(locked: true);
    }
    return PinAttempt(triesLeft: _maxFails - _pinFails);
  }

  Future<void> persistPinLock() async {
    try {
      final left = (_lockBaseMs - _lockSw.elapsedMilliseconds).clamp(0, _lockBaseMs).toInt();
      if (_pinFails == 0 && _pinLockLevel == 0 && left == 0) {
        await _secure.delete(key: 'pin_lock');
      } else {
        await _secure.write(key: 'pin_lock', value: jsonEncode({'f': _pinFails, 'v': _pinLockLevel, 'ms': left}));
      }
    } catch (_) {}
  }

  Future<void> _resetLock() async {
    _pinFails = 0;
    _pinLockLevel = 0;
    _lockBaseMs = 0;
    _lockSw.reset();
    await persistPinLock();
  }

  Future<void> clearPin() async {
    _pinHash = null;
    _pinSalt = null;
    try {
      await _secure.delete(key: 'pin_v2');
    } catch (_) {}
    for (final k in const ['pin_on', 'pin_hash', 'pin_salt', 'pin_len', 'bio', 'pin_fails', 'pin_lock_level', 'pin_lock_until']) {
      await prefs.remove(k);
    }
    await _resetLock();
    notifyListeners();
  }

  // ====================== PENGINGAT, BIOMETRIK, BATAS AI ======================
  VoidCallback? onScheduleDirty;
  Timer? _schedTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (onScheduleDirty != null) {
      _schedTimer?.cancel();
      _schedTimer = Timer(const Duration(seconds: 3), () => onScheduleDirty?.call());
    }
  }

  /// Memberi tahu pendengar bahwa pengaturan di luar AppState berubah (mis. cadangan otomatis).
  void refresh() => notifyListeners();

  bool get remindersOn => prefs.getBool('rem_bills') ?? false;
  bool get dailyReminder => prefs.getBool('rem_daily') ?? false;
  int get reminderHour => prefs.getInt('rem_hour') ?? 20;
  int get reminderMinute => prefs.getInt('rem_min') ?? 0;
  bool get biometricOn => prefs.getBool('bio') ?? false;
  int get aiDailyLimit => prefs.getInt('ai_limit') ?? 60;

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  int get aiUsedToday => prefs.getString('ai_day') == _today() ? (prefs.getInt('ai_count') ?? 0) : 0;
  bool get aiAllowed => aiDailyLimit <= 0 || aiUsedToday < aiDailyLimit;

  Future<void> aiRecord() async {
    final used = aiUsedToday;
    await prefs.setString('ai_day', _today());
    await prefs.setInt('ai_count', used + 1);
    notifyListeners();
  }

  Future<void> setPrefBool(String k, bool v) async {
    await prefs.setBool(k, v);
    notifyListeners();
  }

  Future<void> setPrefInt(String k, int v) async {
    await prefs.setInt(k, v);
    notifyListeners();
  }

  /// Batas anggaran efektif pada [month], memperhitungkan rollover bila aktif.
  double budgetLimit(Budget b, DateTime month) {
    final from = b.rolloverFrom;
    final m = DateTime(month.year, month.month);
    if (from == null || !DateTime(from.year, from.month).isBefore(m)) return b.amount;
    final spent = <double>[];
    var cur = DateTime(from.year, from.month);
    var guard = 0;
    while (cur.isBefore(m) && guard++ < 36) {
      spent.add(spentCat(b.categoryId, cur));
      cur = DateTime(cur.year, cur.month + 1);
    }
    return rolloverLimit(b.amount, spent);
  }

  // ====================== ONBOARDING & CHAT ======================
  bool get onboarded => prefs.getBool('onboarded') ?? txs.isNotEmpty;

  Future<void> finishOnboarding() async {
    await prefs.setBool('onboarded', true);
    notifyListeners();
  }

  String? get chatJson => prefs.getString('chat');

  Future<void> saveChat(String? json) async {
    if (json == null) {
      await prefs.remove('chat');
    } else {
      await prefs.setString('chat', json);
    }
  }

  // ====================== FAVORIT & CADANGAN ======================
  List<Map<String, dynamic>> get templates {
    final raw = prefs.getString('templates');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTemplates(List<Map<String, dynamic>> l) async {
    await prefs.setString('templates', jsonEncode(l));
    notifyListeners();
  }

  DateTime? get lastBackup {
    final v = prefs.getInt('last_backup');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> markBackup() async {
    await prefs.setInt('last_backup', DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  // ====================== AI ======================
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  String? aiKey;
  bool get aiKeySet => aiKey != null && aiKey!.isNotEmpty;
  String get aiProvider => prefs.getString('ai_provider') ?? 'gemini';
  AiProvider get aiProviderInfo => aiProviderById(aiProvider);
  String get aiModel {
    final m = prefs.getString('ai_model');
    return (m == null || m.isEmpty) ? aiProviderInfo.defaultModel : m;
  }

  /// Alamat dasar API; untuk penyedia "Lainnya" diisi pengguna.
  String get aiBaseUrl => aiProviderInfo.custom ? (prefs.getString('ai_base') ?? '') : aiProviderInfo.baseUrl;
  String get aiLabel => '${aiProviderInfo.name} · $aiModel';
  bool get aiConsent => prefs.getBool('ai_consent') ?? false;

  Future<void> loadAiKey() async {
    try {
      aiKey = await _secure.read(key: 'ai_key');
      // Kunci lama (versi sebelum penyedia dipilih) tidak boleh terkirim ke penyedia lain: buang.
      if (aiKey != null && prefs.getString('ai_provider') == null) {
        await _secure.delete(key: 'ai_key');
        aiKey = null;
      }
    } catch (_) {
      aiKey = null;
    }
  }

  /// Mengembalikan false jika penyimpanan aman gagal (kunci hanya bertahan selama sesi).
  Future<bool> setAiKey(String? k) async {
    var ok = true;
    try {
      if (k == null || k.isEmpty) {
        await _secure.delete(key: 'ai_key');
      } else {
        await _secure.write(key: 'ai_key', value: k);
      }
    } catch (_) {
      ok = false;
    }
    aiKey = (k == null || k.isEmpty) ? null : k;
    notifyListeners();
    return ok;
  }

  Future<void> setAiModel(String m) async {
    await prefs.setString('ai_model', m);
    notifyListeners();
  }

  /// Menyimpan penyedia, model, dan (untuk "Lainnya") alamat API sekaligus.
  Future<void> setAiConfig({required String provider, required String model, String? baseUrl}) async {
    await prefs.setString('ai_provider', provider);
    await prefs.setString('ai_model', model);
    if (baseUrl != null) await prefs.setString('ai_base', baseUrl.trim());
    notifyListeners();
  }

  Future<void> setAiConsent(bool v) async {
    await prefs.setBool('ai_consent', v);
    notifyListeners();
  }

  // ====================== LOAD / SEED ======================
  Future<void> load() async {
    currencySymbol = currency;
    await loadAiKey();
    await loadPin();
    wallets = (await db.all('wallets')).map(Wallet.fromMap).toList()..sort((a, b) => a.sort.compareTo(b.sort));
    cats = (await db.all('categories')).map(Cat.fromMap).toList();
    if (wallets.isEmpty && cats.isEmpty) {
      await _seed();
    }
    txs = (await db.all('transactions')).map(Tx.fromMap).toList();
    budgets = (await db.all('budgets')).map(Budget.fromMap).toList();
    goals = (await db.all('goals')).map(Goal.fromMap).toList();
    recurrings = (await db.all('recurring')).map(Recurring.fromMap).toList();
    debts = (await db.all('debts')).map(Debt.fromMap).toList();
    final pays = (await db.all('debt_payments')).map(DebtPayment.fromMap).toList();
    for (final d in debts) {
      d.payments = pays.where((p) => p.debtId == d.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    }
    _recalc();
  }

  Future<void> _seed() async {
    wallets = [
      Wallet(id: uid(), name: 'Tunai', type: 'cash', color: kColorValues[3], icon: 19, sort: 0),
      Wallet(id: uid(), name: 'Rekening Bank', type: 'bank', color: kColorValues[6], icon: 17, sort: 1),
      Wallet(id: uid(), name: 'E-Wallet', type: 'ewallet', color: kColorValues[8], icon: 16, sort: 2),
    ];
    Cat c(String n, bool e, int col, int ic) => Cat(id: uid(), name: n, isExpense: e, color: kColorValues[col], icon: ic);
    cats = [
      c('Makanan', true, 1, 0),
      c('Kopi & Jajan', true, 10, 21),
      c('Transportasi', true, 6, 1),
      c('BBM', true, 2, 27),
      c('Belanja', true, 9, 2),
      c('Tagihan', true, 0, 3),
      c('Listrik & Air', true, 5, 28),
      c('Pulsa & Internet', true, 7, 12),
      c('Hiburan', true, 8, 4),
      c('Kesehatan', true, 4, 5),
      c('Pendidikan', true, 6, 6),
      c('Rumah', true, 10, 7),
      c('Hadiah & Donasi', true, 9, 24),
      c('Lainnya', true, 11, 20),
      c('Gaji', false, 3, 8),
      c('Bonus', false, 1, 9),
      c('Usaha', false, 5, 31),
      c('Investasi', false, 8, 11),
      c('Lainnya', false, 11, 19),
    ];
    await db.putAll('wallets', wallets.map((e) => e.toMap()).toList());
    await db.putAll('categories', cats.map((e) => e.toMap()).toList());
  }

  void _apply(Map<String, double> m, Tx t) {
    switch (t.type) {
      case TxType.income:
        m[t.walletId] = (m[t.walletId] ?? 0) + t.amount;
        break;
      case TxType.expense:
        m[t.walletId] = (m[t.walletId] ?? 0) - t.amount;
        break;
      case TxType.transfer:
        m[t.walletId] = (m[t.walletId] ?? 0) - t.amount;
        if (t.toWalletId != null) m[t.toWalletId!] = (m[t.toWalletId!] ?? 0) + t.amount;
        break;
    }
  }

  void _recalc() {
    _sumCache.clear();
    _catCache.clear();
    _streak = null;
    _bal.clear();
    for (final w in wallets) {
      _bal[w.id] = w.initial;
    }
    for (final t in txs) {
      _apply(_bal, t);
    }
  }

  void _changed() {
    _recalc();
    notifyListeners();
  }

  // ====================== LOOKUP & AGREGAT ======================
  Wallet? wallet(String? id) {
    for (final w in wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  Cat? cat(String? id) {
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Wallet> get activeWallets => wallets.where((w) => !w.archived).toList();

  double balanceOf(String id) => _bal[id] ?? 0;

  double get netWorth => activeWallets.fold(0.0, (a, w) => a + balanceOf(w.id));

  /// Kekayaan bersih (dompet aktif) tepat sebelum tanggal [end].
  double netWorthBefore(DateTime end) {
    final m = <String, double>{for (final w in wallets) w.id: w.initial};
    for (final t in txs) {
      if (t.date.isBefore(end)) _apply(m, t);
    }
    return activeWallets.fold(0.0, (a, w) => a + (m[w.id] ?? 0));
  }

  List<Tx> between(DateTime from, DateTime to) =>
      txs.where((t) => !t.date.isBefore(from) && t.date.isBefore(to)).toList()..sort((a, b) => b.date.compareTo(a.date));

  double sumBetween(DateTime from, DateTime to, TxType type) {
    final key = '${type.index}|${from.millisecondsSinceEpoch}|${to.millisecondsSinceEpoch}';
    return _sumCache.putIfAbsent(
      key,
      () => txs
          .where((t) => t.type == type && !t.neutral && !t.date.isBefore(from) && t.date.isBefore(to))
          .fold(0.0, (a, t) => a + t.amount),
    );
  }

  Map<String?, double> byCategory(DateTime from, DateTime to, TxType type) {
    final key = '${type.index}|${from.millisecondsSinceEpoch}|${to.millisecondsSinceEpoch}';
    final cached = _catCache.putIfAbsent(key, () {
      final out = <String?, double>{};
      for (final t in txs) {
        if (t.type == type && !t.neutral && !t.date.isBefore(from) && t.date.isBefore(to)) {
          out[t.categoryId] = (out[t.categoryId] ?? 0) + t.amount;
        }
      }
      return out;
    });
    return Map<String?, double>.from(cached);
  }

  /// Jumlah hari berturut-turut (sampai hari ini/kemarin) yang memiliki catatan.
  int get streak => _streak ??= _computeStreak();

  int _computeStreak() {
    final days = <DateTime>{for (final t in txs) dayOnly(t.date)};
    var d = dayOnly(DateTime.now());
    if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  double spentCat(String catId, DateTime month) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return txs
        .where((t) => t.type == TxType.expense && t.categoryId == catId && !t.date.isBefore(from) && t.date.isBefore(to))
        .fold(0.0, (a, t) => a + t.amount);
  }

  List<Tx> get recent => ([...txs]..sort((a, b) => b.date.compareTo(a.date))).take(5).toList();

  // ====================== TRANSAKSI ======================
  Future<void> saveTx(Tx t) async {
    final i = txs.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      txs[i] = t;
    } else {
      txs.add(t);
    }
    _changed();
    await db.put('transactions', t.toMap());
  }

  Future<Tx?> deleteTx(String id) async {
    final i = txs.indexWhere((x) => x.id == id);
    if (i < 0) return null;
    final t = txs.removeAt(i);
    _changed();
    await db.remove('transactions', id);
    return t;
  }

  Future<void> importTxs(List<Tx> list) async {
    if (list.isEmpty) return;
    txs.addAll(list);
    _changed();
    await db.putAll('transactions', list.map((t) => t.toMap()).toList());
  }

  Future<void> deleteTxs(Set<String> ids) async {
    if (ids.isEmpty) return;
    txs.removeWhere((t) => ids.contains(t.id));
    _changed();
    final all = ids.toList();
    for (var i = 0; i < all.length; i += 400) {
      final chunk = all.sublist(i, min(i + 400, all.length));
      await db.raw.delete('transactions', where: 'id IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: chunk);
    }
  }

  // ====================== DOMPET ======================
  Future<void> saveWallet(Wallet w) async {
    final i = wallets.indexWhere((x) => x.id == w.id);
    if (i >= 0) {
      wallets[i] = w;
    } else {
      w.sort = wallets.length;
      wallets.add(w);
    }
    _changed();
    await db.put('wallets', w.toMap());
  }

  Future<void> toggleArchive(Wallet w) async {
    w.archived = !w.archived;
    _changed();
    await db.put('wallets', w.toMap());
  }

  /// Mencocokkan saldo dompet dengan saldo sebenarnya. Selisih dicatat sebagai koreksi netral
  /// (mengubah saldo, tetapi tidak dihitung sebagai pemasukan/pengeluaran).
  Future<double> adjustBalance(Wallet w, double actual) async {
    final diff = actual - balanceOf(w.id);
    if (diff == 0) return 0;
    await saveTx(Tx(
      id: uid(),
      type: diff < 0 ? TxType.expense : TxType.income,
      amount: diff.abs(),
      walletId: w.id,
      date: DateTime.now(),
      note: 'Penyesuaian saldo',
      neutral: true,
    ));
    return diff;
  }

  Future<bool> deleteWallet(String id) async {
    if (wallets.length <= 1) return false;
    if (txs.any((t) => t.walletId == id || t.toWalletId == id)) return false;
    if (recurrings.any((r) => r.walletId == id || r.toWalletId == id)) return false;
    wallets.removeWhere((w) => w.id == id);
    _changed();
    await db.remove('wallets', id);
    return true;
  }

  // ====================== KATEGORI ======================
  Future<void> saveCat(Cat c) async {
    final i = cats.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      cats[i] = c;
    } else {
      cats.add(c);
    }
    notifyListeners();
    await db.put('categories', c.toMap());
  }

  Future<void> deleteCat(String id) async {
    cats.removeWhere((c) => c.id == id);
    budgets.removeWhere((b) => b.categoryId == id);
    for (final t in txs) {
      if (t.categoryId == id) t.categoryId = null;
    }
    for (final r in recurrings) {
      if (r.categoryId == id) r.categoryId = null;
    }
    _changed();
    await db.raw.transaction((x) async {
      await x.delete('categories', where: 'id = ?', whereArgs: [id]);
      await x.delete('budgets', where: 'category_id = ?', whereArgs: [id]);
      await x.update('transactions', {'category_id': null}, where: 'category_id = ?', whereArgs: [id]);
      await x.update('recurring', {'category_id': null}, where: 'category_id = ?', whereArgs: [id]);
    });
  }

  // ====================== ANGGARAN ======================
  Future<void> saveBudget(Budget b) async {
    final i = budgets.indexWhere((x) => x.id == b.id);
    if (i >= 0) {
      budgets[i] = b;
    } else {
      budgets.add(b);
    }
    notifyListeners();
    await db.put('budgets', b.toMap());
  }

  Future<void> deleteBudget(String id) async {
    budgets.removeWhere((b) => b.id == id);
    notifyListeners();
    await db.remove('budgets', id);
  }

  // ====================== TARGET ======================
  Future<void> saveGoal(Goal g) async {
    final i = goals.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      goals[i] = g;
    } else {
      goals.add(g);
    }
    notifyListeners();
    await db.put('goals', g.toMap());
  }

  Future<void> deleteGoal(String id) async {
    goals.removeWhere((g) => g.id == id);
    notifyListeners();
    await db.remove('goals', id);
  }

  // ====================== BERULANG ======================
  Future<void> saveRecurring(Recurring r) async {
    final i = recurrings.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      recurrings[i] = r;
    } else {
      recurrings.add(r);
    }
    notifyListeners();
    await db.put('recurring', r.toMap());
  }

  Future<void> deleteRecurring(String id) async {
    recurrings.removeWhere((r) => r.id == id);
    notifyListeners();
    await db.remove('recurring', id);
  }

  /// Membuat transaksi otomatis untuk aturan berulang yang sudah jatuh tempo.
  Future<int> processRecurring() async {
    final today = dayOnly(DateTime.now());
    final created = <Tx>[];
    final changed = <Recurring>[];
    for (final r in recurrings) {
      if (!r.active) continue;
      var touched = false;
      var guard = 0;
      while (!r.nextDate.isAfter(today) && guard++ < 500) {
        if (r.endDate != null && r.nextDate.isAfter(r.endDate!)) break;
        created.add(Tx(
          id: uid(),
          type: r.type,
          amount: r.amount,
          walletId: r.walletId,
          toWalletId: r.toWalletId,
          categoryId: r.categoryId,
          date: r.nextDate,
          note: r.note,
          recurringId: r.id,
        ));
        r.nextDate = nextOccurrence(r.nextDate, r.freq, r.anchorDay);
        touched = true;
      }
      if (r.endDate != null && r.nextDate.isAfter(r.endDate!) && r.active) {
        r.active = false;
        touched = true;
      }
      if (touched) changed.add(r);
    }
    if (created.isEmpty && changed.isEmpty) return 0;
    txs.addAll(created);
    _changed();
    await db.putAll('transactions', created.map((t) => t.toMap()).toList());
    await db.putAll('recurring', changed.map((r) => r.toMap()).toList());
    return created.length;
  }

  // ====================== HUTANG ======================
  Future<void> saveDebt(Debt d) async {
    final i = debts.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      debts[i] = d;
    } else {
      debts.add(d);
    }
    d.settled = d.paid >= d.amount;
    notifyListeners();
    await db.put('debts', d.toMap());
    final li = txs.indexWhere((t) => t.externalId == 'debt:${d.id}');
    if (li >= 0 && txs[li].amount != d.amount) {
      txs[li].amount = d.amount;
      await saveTx(txs[li]);
    }
  }

  /// Membuat catatan hutang/piutang; bila [walletId] diisi, arus uangnya dicatat netral di dompet itu.
  Future<void> createDebt(Debt d, {String? walletId}) async {
    await saveDebt(d);
    if (walletId != null && wallet(walletId) != null) {
      await saveTx(Tx(
        id: uid(),
        type: d.owedToMe ? TxType.expense : TxType.income,
        amount: d.amount,
        walletId: walletId,
        date: DateTime.now(),
        note: d.owedToMe ? 'Pinjaman ke ${d.person}' : 'Pinjaman dari ${d.person}',
        externalId: 'debt:${d.id}',
        neutral: true,
      ));
    }
  }

  /// Patungan: bagian Anda jadi pengeluaran biasa; talangan untuk teman jadi piutang (arus netral).
  Future<void> createSplit({
    required double total,
    required List<String> others,
    required String walletId,
    required String? categoryId,
    required String note,
  }) async {
    if (others.isEmpty || total <= 0) return;
    final each = splitEach(total, others.length + 1);
    if (each <= 0) return;
    final mine = total - each * others.length;
    final now = DateTime.now();
    await saveTx(Tx(
      id: uid(),
      type: TxType.expense,
      amount: mine,
      walletId: walletId,
      categoryId: categoryId,
      date: now,
      note: note.isEmpty ? 'Patungan' : '$note (bagian saya)',
    ));
    for (final name in others) {
      await createDebt(
        Debt(id: uid(), person: name, amount: each, owedToMe: true, note: note.isEmpty ? 'Patungan' : 'Patungan: $note'),
        walletId: walletId,
      );
    }
  }

  Future<void> _removeLinked(String key) async {
    final ids = txs.where((t) => t.externalId == key).map((t) => t.id).toSet();
    if (ids.isNotEmpty) await deleteTxs(ids);
  }

  Future<void> deleteDebt(String id) async {
    final old = debts.where((d) => d.id == id).toList();
    for (final d in old) {
      for (final p in d.payments) {
        await _removeLinked('pay:${p.id}');
      }
    }
    await _removeLinked('debt:$id');
    debts.removeWhere((d) => d.id == id);
    notifyListeners();
    await db.raw.transaction((x) async {
      await x.delete('debt_payments', where: 'debt_id = ?', whereArgs: [id]);
      await x.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> addPayment(Debt d, double amount, String note, {String? walletId}) async {
    final p = DebtPayment(id: uid(), debtId: d.id, amount: amount, date: DateTime.now(), note: note);
    d.payments.insert(0, p);
    d.settled = d.paid >= d.amount;
    notifyListeners();
    await db.put('debt_payments', p.toMap());
    await db.put('debts', d.toMap());
    if (walletId != null && wallet(walletId) != null) {
      await saveTx(Tx(
        id: uid(),
        type: d.owedToMe ? TxType.income : TxType.expense,
        amount: amount,
        walletId: walletId,
        date: DateTime.now(),
        note: d.owedToMe ? 'Pelunasan dari ${d.person}' : 'Bayar hutang ke ${d.person}',
        externalId: 'pay:${p.id}',
        neutral: true,
      ));
    }
  }

  Future<void> deletePayment(Debt d, String paymentId) async {
    d.payments.removeWhere((p) => p.id == paymentId);
    await _removeLinked('pay:$paymentId');
    d.settled = d.paid >= d.amount;
    notifyListeners();
    await db.remove('debt_payments', paymentId);
    await db.put('debts', d.toMap());
  }

  // ====================== DATA ======================
  String exportCsv() {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Tanggal,Tipe,Kategori,Dompet,Dompet Tujuan,Nominal,Catatan,Netral\n');
    final sorted = [...txs]..sort((a, b) => a.date.compareTo(b.date));
    for (final t in sorted) {
      final tipe = switch (t.type) {
        TxType.income => 'Pemasukan',
        TxType.expense => 'Pengeluaran',
        TxType.transfer => 'Pindah dana',
      };
      b.writeln([
        t.date.toIso8601String().substring(0, 10),
        tipe,
        q(cat(t.categoryId)?.name ?? ''),
        q(wallet(t.walletId)?.name ?? ''),
        q(wallet(t.toWalletId)?.name ?? ''),
        t.amount.toStringAsFixed(0),
        q(t.note),
        t.neutral ? 'ya' : 'tidak',
      ].join(','));
    }
    return b.toString();
  }

  Future<String> exportBackup({String? password}) async {
    final data = await db.dump();
    final plain = jsonEncode({
      'app': 'catatan_uang',
      'version': 3,
      'exported': DateTime.now().toIso8601String(),
      'data': data,
    });
    if (password != null && password.isNotEmpty) return encryptBackup(plain, password);
    return plain;
  }

  /// Memeriksa isi cadangan SEBELUM database disentuh. Melempar [FormatException] bila ada yang janggal,
  /// sehingga file rusak atau dimanipulasi tidak bisa menghapus data yang ada atau membuat aplikasi crash.
  static Map<String, List<DbMap>> validateBackup(Map<String, dynamic> j) {
    if (j['app'] != 'catatan_uang') throw const FormatException('Bukan file cadangan Tertata');
    final v = j['version'];
    if (v is! int || v < 1 || v > 3) throw const FormatException('Versi cadangan tidak dikenali');
    final d = j['data'];
    if (d is! Map) throw const FormatException('Data cadangan kosong');
    const needNum = {
      'wallets': ['initial'],
      'transactions': ['amount', 'date'],
      'budgets': ['amount'],
      'goals': ['target', 'saved'],
      'recurring': ['amount', 'next_date'],
      'debts': ['amount'],
      'debt_payments': ['amount', 'date'],
    };
    const txTypes = {'income', 'expense', 'transfer'};
    final out = <String, List<DbMap>>{};
    for (final t in Db.tables) {
      final rows = d[t] ?? <dynamic>[];
      if (rows is! List) throw FormatException('Tabel $t rusak');
      if (rows.length > 500000) throw FormatException('Tabel $t terlalu besar');
      final ids = <String>{};
      final list = <DbMap>[];
      for (final e in rows) {
        if (e is! Map) throw FormatException('Baris di $t rusak');
        final m = Map<String, Object?>.from(e);
        final id = m['id'];
        if (id is! String || id.isEmpty || id.length > 100) throw FormatException('ID di $t tidak valid');
        if (!ids.add(id)) throw FormatException('ID ganda di $t');
        for (final k in needNum[t] ?? const <String>[]) {
          final x = m[k];
          if (x is! num || !x.isFinite) throw FormatException('Nilai $k di $t tidak valid');
          if (k == 'amount' && x < 0) throw FormatException('Nominal negatif di $t');
        }
        if (t == 'transactions' && !txTypes.contains(m['type'])) throw const FormatException('Jenis transaksi tidak dikenal');
        list.add(m);
      }
      out[t] = list;
    }
    return out;
  }

  Future<void> importBackup(String raw, {bool merge = false}) async {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) throw const FormatException('Bukan file cadangan Tertata');
    final data = validateBackup(j);
    if (merge) {
      await db.merge(data);
    } else {
      await db.restore(data);
    }
    await load();
    await processRecurring();
    notifyListeners();
  }

  /// Menghapus semua data pengguna: database, riwayat chat asisten, favorit, jejak cadangan,
  /// hitungan pemakaian AI, persetujuan AI, dan kunci API. Tema, aksen, dan mata uang dipertahankan.
  Future<void> resetAll() async {
    await db.clearAll();
    for (final k in const ['chat', 'templates', 'last_backup', 'ai_day', 'ai_count', 'ai_consent']) {
      await prefs.remove(k);
    }
    await setAiKey(null);
    await AutoBackup.wipe(prefs);
    await load();
    notifyListeners();
  }
}
