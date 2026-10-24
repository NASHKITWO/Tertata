import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../common.dart';

/// Pengingat lokal (tanpa server). Semua jadwal dibuat ulang setiap data berubah atau app dibuka.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  static Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      var ok = true;
      if (a != null) ok = (await a.requestNotificationsPermission()) ?? false;
      if (i != null) ok = (await i.requestPermissions(alert: true, badge: true, sound: true)) ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<void> schedule(AppState s) async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();
      if (!s.remindersOn && !s.dailyReminder) return;

      final now = DateTime.now();
      final items = <(DateTime, String, String)>[];

      if (s.dailyReminder) {
        for (var d = 0; d < 14; d++) {
          items.add((
            DateTime(now.year, now.month, now.day + d, s.reminderHour, s.reminderMinute),
            'Catat keuangan hari ini',
            'Sudah mencatat pemasukan dan pengeluaran hari ini?',
          ));
        }
      }

      if (s.remindersOn) {
        for (final r in s.recurrings.where((r) => r.active && r.type == TxType.expense)) {
          final name = s.cat(r.categoryId)?.name ?? 'Tagihan';
          var d = r.nextDate;
          var n = 0;
          while (n < 3 && d.difference(now).inDays <= 30) {
            if (r.endDate != null && d.isAfter(r.endDate!)) break;
            items.add((DateTime(d.year, d.month, d.day, 9), 'Tagihan $name', '${rp(r.amount)} jatuh tempo hari ini'));
            items.add((DateTime(d.year, d.month, d.day - 1, 9), 'Tagihan $name besok', '${rp(r.amount)} jatuh tempo besok'));
            d = nextOccurrence(d, r.freq, r.anchorDay);
            n++;
          }
        }
        for (final d in s.debts.where((d) => !d.settled && d.due != null)) {
          final due = d.due!;
          final what = d.owedToMe ? 'Piutang' : 'Hutang';
          items.add((DateTime(due.year, due.month, due.day, 9), '$what ${d.person} jatuh tempo', 'Sisa ${rp(d.remaining)}'));
          items.add((DateTime(due.year, due.month, due.day - 1, 9), '$what ${d.person} besok', 'Sisa ${rp(d.remaining)}'));
        }
      }

      items.sort((a, b) => a.$1.compareTo(b.$1));
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Pengingat',
          channelDescription: 'Pengingat tagihan, jatuh tempo, dan pencatatan harian',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
      var id = 1;
      for (final it in items) {
        if (!it.$1.isAfter(now)) continue;
        if (id > 60) break;
        await _plugin.zonedSchedule(
          id++,
          it.$2,
          it.$3,
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, it.$1.millisecondsSinceEpoch),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Pengingat bersifat opsional; kegagalan tidak boleh mengganggu aplikasi.
    }
  }
}
