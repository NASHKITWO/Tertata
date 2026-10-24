import 'dart:async';
import 'dart:convert';
import '../common.dart';
import 'native_bridge.dart';

/// Mengirim ringkasan keuangan ke widget layar utama (Android).
/// Secara bawaan saldo DISEMBUNYIKAN di widget karena terlihat tanpa membuka kunci aplikasi.
class WidgetSync {
  static Timer? _t;
  static const prefKey = 'widget_show';

  static bool showBalance(AppState s) => s.prefs.getBool(prefKey) ?? false;

  /// Isi widget (sudah diformat). Dipisah agar mudah dites.
  static Map<String, String> payload({
    required bool show,
    required double balance,
    required double spent,
    required double perDay,
  }) {
    if (!show) {
      return {'balance': '$currencySymbol••••••', 'detail': 'Ketuk untuk membuka', 'perDay': ''};
    }
    return {
      'balance': rp(balance),
      'detail': 'Keluar bulan ini ${rp(spent)}',
      'perDay': perDay > 0 ? 'Aman ${rp(perDay)}/hari' : '',
    };
  }

  static Map<String, String> fromState(AppState s, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final m0 = DateTime(n.year, n.month);
    final m1 = DateTime(n.year, n.month + 1);
    final inc = s.sumBetween(m0, m1, TxType.income);
    final exp = s.sumBetween(m0, m1, TxType.expense);
    final limit = s.budgets.fold<double>(0.0, (a, b) => a + s.budgetLimit(b, n));
    final bspent = s.budgets.fold<double>(0.0, (a, b) => a + s.spentCat(b.categoryId, n));
    final remaining = limit > 0 ? limit - bspent : inc - exp;
    final daysLeft = DateTime(n.year, n.month + 1, 0).day - n.day + 1;
    final perDay = remaining > 0 && daysLeft > 0 ? remaining / daysLeft : 0.0;
    return payload(show: showBalance(s), balance: s.netWorth, spent: exp, perDay: perDay);
  }

  /// Menjadwalkan pembaruan (ditunda sebentar agar rentetan perubahan jadi satu kali kirim).
  static void push(AppState s, {Duration delay = const Duration(seconds: 1)}) {
    if (!NativeBridge.supported) return;
    _t?.cancel();
    _t = Timer(delay, () => NativeBridge.updateWidget(jsonEncode(fromState(s))));
  }
}
