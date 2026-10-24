import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'common.dart';
import 'data/db.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';
import 'services/auto_backup.dart';
import 'services/crash_log.dart';
import 'services/native_bridge.dart';
import 'services/reminders.dart';
import 'services/widget_sync.dart';
import 'services/security.dart';
import 'services/update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Terjadi kesalahan pada tampilan ini. Kembali ke halaman sebelumnya dan coba lagi.', textAlign: TextAlign.center),
            ),
          ),
        );
  }
  try {
    await initializeDateFormatting('id_ID');
    final prefs = await SharedPreferences.getInstance();
    CrashLog.install(prefs);
    final db = Db();
    await db.open();
    final state = AppState(db, prefs);
    await state.load();
    await state.processRecurring();
    NativeBridge.setSecure(prefs.getBool('secure_screen') ?? false);
    state.onScheduleDirty = () {
      Reminders.schedule(state);
      WidgetSync.push(state);
    };
    Reminders.schedule(state);
    WidgetSync.push(state);
    runApp(AppScope(state: state, child: const App()));
    unawaited(UpdateCheck.autoCheck(prefs));
    final autoBackup = _AutoBackupRunner(prefs, state);
    WidgetsBinding.instance.addObserver(autoBackup);
    unawaited(autoBackup.run());
  } catch (e, st) {
    await CrashLog.record(e, st);
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aplikasi gagal dimulai.\n\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
  }
}

/// Menjalankan cadangan otomatis saat aplikasi dibuka dan setiap kali kembali ke layar depan.
class _AutoBackupRunner with WidgetsBindingObserver {
  _AutoBackupRunner(this.prefs, this.state);
  final SharedPreferences prefs;
  final AppState state;
  bool _running = false;

  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      await AutoBackup.runIfDue(prefs, (pw) => state.exportBackup(password: pw));
    } catch (e, st) {
      await CrashLog.record(e, st);
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(run());
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MaterialApp(
      title: 'Tertata',
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: buildTheme(s.accent, Brightness.light),
      darkTheme: buildTheme(s.accent, Brightness.dark),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Pada layar lebar (tablet/landscape) isi dibatasi agar tetap nyaman dibaca.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Batasi pembesaran font sistem agar kartu dan angka tidak terpotong.
        minScaleFactor: .9,
        maxScaleFactor: 1.3,
        child: LockGate(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
      home: s.onboarded ? const HomeShell() : const OnboardingPage(),
    );
  }
}
