import 'package:flutter/material.dart';

// Font dibundel sebagai aset (assets/fonts), jadi tidak butuh internet.
const kFontHead = 'PlusJakartaSans';
const kFontBody = 'Inter';

// Warna semantik: dipakai konsisten di seluruh aplikasi.
// Nada tengah dipilih agar terbaca di latar terang maupun gelap.
const kIncome = Color(0xFF1F9D5C); // hijau: pemasukan, aman
const kExpense = Color(0xFFE0592A); // jingga-bata: pengeluaran biasa (tidak menakutkan)
const kTransfer = Color(0xFF5D7DA3); // biru-abu: pindah dana, netral
const kWarn = Color(0xFFCA8A04); // kuning tua: mendekati batas
const kDanger = Color(0xFFDC2626); // merah: hanya untuk bahaya (lewat batas, terlambat, hapus)

const kAccents = <Color>[
  Color(0xFF0F766E), // Teal
  Color(0xFF4F46E5), // Indigo
  Color(0xFF2563EB), // Biru
  Color(0xFF7C3AED), // Ungu
  Color(0xFFDB2777), // Pink
  Color(0xFFEA580C), // Oranye
  Color(0xFF059669), // Zamrud
  Color(0xFFE11D48), // Delima
];
const kAccentNames = <String>['Teal', 'Indigo', 'Biru', 'Ungu', 'Pink', 'Oranye', 'Zamrud', 'Delima'];

extension ColorSoft on Color {
  Color soft([double o = .12]) => withValues(alpha: o);
}

Color shiftHue(Color c, double deg) {
  final h = HSLColor.fromColor(c);
  return h.withHue((h.hue + deg) % 360).toColor();
}

/// Gradien "hero" untuk kartu utama: turunan dari warna aksen dengan pergeseran rona halus.
LinearGradient heroGradient(Color base) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(base, Colors.black, .06)!, Color.lerp(base, Colors.black, .16)!],
    );

/// Warna isian (kartu saldo, gelembung chat, tombol kirim). Di tema gelap, `primary` Material 3 berupa nada terang,
/// sehingga teks putih di atasnya tidak terbaca; di sana dipakai `primaryContainer` yang gelap.
Color fillOf(BuildContext c) {
  final t = Theme.of(c);
  return t.brightness == Brightness.dark ? t.colorScheme.primaryContainer : t.colorScheme.primary;
}

/// Warna teks/ikon di atas [fillOf]; selalu kontras di tema terang maupun gelap.
Color onFillOf(BuildContext c) {
  final t = Theme.of(c);
  return t.brightness == Brightness.dark ? t.colorScheme.onPrimaryContainer : t.colorScheme.onPrimary;
}

Color surfaceOf(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1D1B18) : const Color(0xFFFFFDF9);

/// Latar halaman netral agar kartu dan angka menjadi fokus. Parameter [accent] dipertahankan demi kompatibilitas.
Color pageTint(Color accent, bool dark) => dark ? const Color(0xFF141311) : const Color(0xFFF6F2EA);

ThemeData buildTheme(Color seed, Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b).copyWith(
    // Garis dan permukaan bernuansa hangat agar tidak terasa seperti template Material bawaan.
    outlineVariant: dark ? const Color(0xFF3B3731) : const Color(0xFFDDD5C6),
  );
  final bg = pageTint(seed, dark);
  final surface = dark ? const Color(0xFF1D1B18) : const Color(0xFFFFFDF9);
  RoundedRectangleBorder shape(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return ThemeData(
    useMaterial3: true,
    // Riak sentuhan biasa; bawaan Android 12+ berupa kilau (InkSparkle) yang terasa generik.
    splashFactory: InkRipple.splashFactory,
    fontFamily: kFontBody,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontFamily: kFontHead, fontWeight: FontWeight.w700, letterSpacing: -.3),
      titleLarge: TextStyle(fontFamily: kFontHead, fontWeight: FontWeight.w700, letterSpacing: -.2),
      titleMedium: TextStyle(fontFamily: kFontHead, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontFamily: kFontHead, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(height: 1.45),
      bodySmall: TextStyle(height: 1.4),
    ),
    visualDensity: VisualDensity.standard,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : scheme.outline),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      shape: shape(12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.primary.soft(.12),
      circularTrackColor: scheme.primary.soft(.12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(fontFamily: kFontHead, fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.soft(.16),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 11, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: shape(14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: shape(14),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape(12), textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: shape(18),
      elevation: 2,
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      shape: shape(20),
      side: BorderSide(color: scheme.outlineVariant.soft(.8)),
      selectedColor: scheme.primary.soft(.12),
      backgroundColor: surface,
      // Warna label harus eksplisit; tanpa ini teks chip bisa tampil putih di atas latar putih.
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurface),
      checkmarkColor: scheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape(12)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.soft(.5), space: 1, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary.soft(.12),
        selectedForegroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
