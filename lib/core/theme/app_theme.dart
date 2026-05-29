import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

// Cairo is declared in pubspec.yaml > flutter > fonts.
// We reference it by the native family name 'Cairo' everywhere in ThemeData.
// GoogleFonts.cairo() is still used for explicit per-widget styles — when
// allowRuntimeFetching is true (default), google_fonts checks the asset
// bundle first (finds Cairo-*.ttf there) and NEVER hits the network.
const String _kCairo = 'Cairo';

/// Builds a TextTheme using the bundled Cairo font directly via the Flutter
/// font registry — bypasses any google_fonts async loading so Arabic glyphs
/// are available from the very first frame.
TextTheme _cairoTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge:   _s(base.displayLarge,  w: FontWeight.w700),
    displayMedium:  _s(base.displayMedium, w: FontWeight.w700),
    displaySmall:   _s(base.displaySmall,  w: FontWeight.w600),
    headlineLarge:  _s(base.headlineLarge, w: FontWeight.w700),
    headlineMedium: _s(base.headlineMedium,w: FontWeight.w600),
    headlineSmall:  _s(base.headlineSmall, w: FontWeight.w600),
    titleLarge:     _s(base.titleLarge,    w: FontWeight.w700),
    titleMedium:    _s(base.titleMedium,   w: FontWeight.w600),
    titleSmall:     _s(base.titleSmall,    w: FontWeight.w600),
    bodyLarge:      _s(base.bodyLarge,     w: FontWeight.w400),
    bodyMedium:     _s(base.bodyMedium,    w: FontWeight.w400),
    bodySmall:      _s(base.bodySmall,     w: FontWeight.w400),
    labelLarge:     _s(base.labelLarge,    w: FontWeight.w600),
    labelMedium:    _s(base.labelMedium,   w: FontWeight.w500),
    labelSmall:     _s(base.labelSmall,    w: FontWeight.w400),
  );
}

TextStyle? _s(TextStyle? base, {required FontWeight w}) =>
    base?.copyWith(fontFamily: _kCairo, fontWeight: w);

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _kCairo,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.accent,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: _cairoTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: GoogleFonts.cairo(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardTheme(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(fontFamily: _kCairo, color: AppColors.textHint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: _kCairo, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: AppColors.textSecondary,
      titleTextStyle: TextStyle(fontFamily: _kCairo, color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle: TextStyle(fontFamily: _kCairo, color: AppColors.textSecondary, fontSize: 13),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textHint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.card,
      ),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _kCairo,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      error: AppColors.accent,
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1D2E),
    ),
    textTheme: _cairoTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
      titleTextStyle: GoogleFonts.cairo(
        color: const Color(0xFF1A1D2E),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardTheme(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(fontFamily: _kCairo, color: Color(0xFF9E9E9E), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: _kCairo, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
    dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 0.5),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: _kCairo, color: Color(0xFF1A1D2E), fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle: TextStyle(fontFamily: _kCairo, color: Color(0xFF757575), fontSize: 13),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary.withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.2),
      ),
    ),
  );
}
