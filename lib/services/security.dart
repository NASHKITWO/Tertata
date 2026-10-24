import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../common.dart';
import 'reminders.dart';

/// Panjang PIN baku. PIN lama (4 digit) tetap bisa dipakai membuka aplikasi sampai diganti.
const kPinLength = 6;

final _localAuth = LocalAuthentication();

Future<bool> biometricAvailable() async {
  try {
    return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAuth() async {
  try {
    return await _localAuth.authenticate(
      localizedReason: 'Buka Tertata',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
    );
  } catch (_) {
    return false;
  }
}

/// Dipakai dari layar yang sudah terbuka (Pengaturan, Atur PIN): mencegah aplikasi
/// terkunci ulang hanya karena dialog biometrik sistem tampil.
Future<bool> biometricAuthSafe(AppState s) async {
  s.suppressLock = true;
  final ok = await biometricAuth();
  Future<void>.delayed(const Duration(milliseconds: 800), () => s.suppressLock = false);
  return ok;
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

/// Keypad PIN: tombol bulat, titik indikator beranimasi, getar saat PIN salah.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.value,
    required this.onDigit,
    required this.onDelete,
    this.error,
    this.onBio,
    this.enabled = true,
  });
  final int length;
  final String value;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final String? error;
  final VoidCallback? onBio;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error == null && widget.error != null) {
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasError = widget.error != null;
    final dotColor = hasError ? cs.error : cs.primary;

    Widget key(String label, {VoidCallback? onTap, IconData? icon, String? semantic}) {
      const size = 74.0;
      if (label.isEmpty && icon == null) return const SizedBox(width: size, height: size);
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: icon != null ? Colors.transparent : cs.primary.soft(.08),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.enabled ? onTap : null,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 27, color: cs.onSurfaceVariant, semanticLabel: semantic)
                  : Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const SizedBox(width: 18),
              keys[i],
            ],
          ]),
        );

    Widget digits(List<String> d) => row([
          for (final x in d)
            key(x, onTap: () {
              HapticFeedback.selectionClick();
              widget.onDigit(x);
            }),
        ]);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: i < widget.value.length ? 17 : 14,
              height: i < widget.value.length ? 17 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < widget.value.length ? dotColor : Colors.transparent,
                border: Border.all(color: i < widget.value.length ? dotColor : dotColor.soft(.55), width: 1.8),
              ),
            ),
        ]),
      ),
      SizedBox(
        height: 52,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: widget.error == null ? 0 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(widget.error ?? ' ', style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
      digits(['1', '2', '3']),
      digits(['4', '5', '6']),
      digits(['7', '8', '9']),
      row([
        widget.onBio == null ? key('') : key('', icon: Icons.fingerprint, onTap: widget.onBio, semantic: 'Masuk dengan biometrik'),
        key('0', onTap: () {
          HapticFeedback.selectionClick();
          widget.onDigit('0');
        }),
        key('', icon: Icons.backspace_outlined, onTap: widget.onDelete, semantic: 'Hapus'),
      ]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked, this.cancelable = false});
  final VoidCallback onUnlocked;
  final bool cancelable;
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String value = '';
  String? error;
  Timer? _tick;
  int _left = 0;
  bool _busy = false;
  AppState? _st;
  bool _ready = false;
  bool _resetAsk = false;
  bool _resetSure = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = AppScope.of(context);
    _st = s;
    _syncLock(s);
    if (!widget.cancelable && s.biometricOn && _left == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bio();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_left > 0) _st?.persistPinLock();
    super.dispose();
  }

  /// Sisa waktu kunci dihitung dari stopwatch (monoton) di AppState, bukan jam HP,
  /// dan disimpan di penyimpanan aman: mengubah jam atau menutup aplikasi tidak menguranginya.
  void _syncLock(AppState s) {
    _tick?.cancel();
    _left = s.pinLockLeft;
    if (_left > 0) {
      var n = 0;
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final left = s.pinLockLeft;
        if (++n % 5 == 0 || left == 0) s.persistPinLock();
        setState(() {
          _left = left;
          if (left == 0) {
            error = null;
            t.cancel();
          }
        });
      });
    }
  }

  Future<void> _resetAll() async {
    final s = AppScope.of(context);
    await s.resetAll();
    await s.clearPin();
    if (mounted) widget.onUnlocked();
  }

  Widget _resetPanel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: cs.errorContainer.soft(.55), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 30),
          const SizedBox(height: 8),
          const Text('Lupa PIN? Hapus semua data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'PIN tidak bisa dipulihkan. Satu-satunya cara adalah menghapus semua data di aplikasi ini (transaksi, anggaran, target, hutang, riwayat chat, dan kunci API AI) lalu memulai dari awal. Jika Anda punya file cadangan, pulihkan setelahnya.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _resetSure,
            onChanged: (v) => setState(() => _resetSure = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Saya mengerti semua data akan terhapus permanen', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _resetAsk = false;
                  _resetSure = false;
                }),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                onPressed: _resetSure ? _resetAll : null,
                child: const Text('Hapus & reset'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _bio() async {
    if (_left > 0) return;
    final ok = await biometricAuth();
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _digit(String d) async {
    final s = AppScope.of(context);
    if (_left > 0 || _busy || value.length >= s.pinLength) return;
    setState(() {
      value += d;
      error = null;
    });
    if (value.length < s.pinLength) return;
    // jeda singkat agar titik terakhir sempat terlihat terisi
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted || value.length != s.pinLength) return;

    _busy = true;
    final r = await s.attemptPin(value);
    _busy = false;
    if (!mounted) return;
    if (r.ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      value = '';
      if (r.locked) {
        error = null;
        _syncLock(s);
      } else {
        error = 'PIN salah. Sisa ${r.triesLeft} percobaan.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final locked = _left > 0;
    final msg = locked ? 'Terlalu banyak percobaan. Coba lagi dalam $_left detik.' : error;
    final showBio = !widget.cancelable && s.biometricOn;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(color: bg),
        child: SafeArea(
          child: Stack(children: [
            if (widget.cancelable)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(tooltip: 'Tutup', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FadeSlideIn(
                    child: Column(children: [
                      const BrandLogo(mark: true, height: 60),
                      const SizedBox(height: 16),
                      Text(widget.cancelable ? 'Verifikasi PIN' : _greeting(), style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text('Masukkan PIN ${s.pinLength} digit', style: TextStyle(color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  if (_resetAsk)
                    _resetPanel(cs)
                  else
                  FadeSlideIn(
                    index: 2,
                    child: PinPad(
                      length: s.pinLength,
                      value: value,
                      error: msg,
                      enabled: !locked,
                      onBio: showBio ? _bio : null,
                      onDigit: _digit,
                      onDelete: () => setState(() {
                        if (value.isNotEmpty) value = value.substring(0, value.length - 1);
                      }),
                    ),
                  ),
                  if (showBio && !_resetAsk) ...[
                    const SizedBox(height: 10),
                    FadeSlideIn(
                      index: 3,
                      child: FilledButton.tonalIcon(
                        onPressed: locked ? null : _bio,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Masuk dengan biometrik'),
                      ),
                    ),
                  ],
                  if (!widget.cancelable && !_resetAsk) ...[
                    const SizedBox(height: 4),
                    TextButton(onPressed: () => setState(() => _resetAsk = true), child: const Text('Lupa PIN?')),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Meminta verifikasi PIN lewat layar penuh. Mengembalikan true jika berhasil.
Future<bool> verifyPinScreen(BuildContext context) async {
  final r = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => LockScreen(cancelable: true, onUnlocked: () => Navigator.pop(ctx, true)),
    ),
  );
  return r ?? false;
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});
  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  int step = 0;
  String first = '';
  String value = '';
  String? error;
  bool busy = false;

  Future<void> _digit(String d) async {
    if (busy || value.length >= kPinLength) return;
    setState(() {
      value += d;
      error = null;
    });
    if (value.length < kPinLength) return;
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted || value.length != kPinLength) return;

    if (step == 0) {
      setState(() {
        first = value;
        value = '';
        step = 1;
      });
      return;
    }
    if (value == first) {
      busy = true;
      final s = AppScope.of(context);
      final saved = await s.setPin(value);
      if (!mounted) return;
      if (!saved) {
        busy = false;
        setState(() {
          value = '';
          first = '';
          step = 0;
          error = 'PIN gagal disimpan di penyimpanan aman perangkat. Coba lagi.';
        });
        return;
      }
      await _offerBiometric(s);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        value = '';
        first = '';
        step = 0;
        error = 'PIN tidak sama. Ulangi dari awal.';
      });
    }
  }

  Future<void> _offerBiometric(AppState s) async {
    if (s.biometricOn || !await biometricAvailable() || !mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 36),
        title: const Text('Aktifkan biometrik?'),
        content: const Text('Buka Tertata lebih cepat dengan sidik jari atau wajah. PIN tetap menjadi cadangan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktifkan')),
        ],
      ),
    );
    if (yes == true && mounted) {
      if (await biometricAuthSafe(s)) await s.setPrefBool('bio', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Atur PIN')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              IconBadge(icon: step == 0 ? Icons.lock_outline : Icons.verified_user_outlined, color: cs.primary, size: 64),
              const SizedBox(height: 18),
              Text(step == 0 ? 'Buat PIN $kPinLength digit' : 'Konfirmasi PIN', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                step == 0 ? 'PIN dipakai untuk membuka Tertata.' : 'Masukkan PIN yang sama sekali lagi.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              PinPad(
                length: kPinLength,
                value: value,
                error: error,
                onDigit: _digit,
                onDelete: () => setState(() {
                  if (value.isNotEmpty) value = value.substring(0, value.length - 1);
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Membungkus seluruh app: mengunci saat kembali dari background dan memproses transaksi berulang.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _covered = false;
  bool _init = false;
  final Stopwatch _awaySw = Stopwatch();
  bool _awayTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _locked = AppScope.of(context).pinEnabled;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = AppScope.of(context);
    // Tutupi isi aplikasi di tampilan aplikasi terbaru agar saldo tidak terlihat.
    if (state == AppLifecycleState.resumed) {
      if (_covered) setState(() => _covered = false);
    } else if (s.pinEnabled && !s.suppressLock && !_covered) {
      setState(() => _covered = true);
    }
    if (state == AppLifecycleState.paused) {
      if (!_locked) {
        _awaySw
          ..reset()
          ..start();
        _awayTracked = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (s.suppressLock) {
        s.suppressLock = false;
      } else if (s.pinEnabled && _awayTracked) {
        final away = _awaySw.elapsed.inSeconds;
        if (away >= s.autoLockSeconds) setState(() => _locked = true);
      }
      _awayTracked = false;
      _awaySw.stop();
      s.processRecurring().then((_) => Reminders.schedule(s));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_covered && !_locked)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(child: BrandLogo(height: 90)),
          ),
        ),
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !_locked,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _locked
                ? LockScreen(key: const ValueKey('lock'), onUnlocked: () => setState(() => _locked = false))
                : const SizedBox.shrink(key: ValueKey('open')),
          ),
        ),
      ),
    ]);
  }
}
