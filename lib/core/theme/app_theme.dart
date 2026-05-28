import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // Cairo is the primary font — bundled locally in assets/fonts/
  // and declared in pubspec.yaml so it works 100% offline.
  // Poppins is kept only for decorative Latin/number text in specific widgets.
  static const String _arabicFont = 'Cairo';

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.cairoTextTheme(base).copyWith(
      displayLarge:   base.displayLarge?.copyWith(fontFamily: _arabicFont),
      displayMedium:  base.displayMedium?.copyWith(fontFamily: _arabicFont),
      displaySmall:   base.displaySmall?.copyWith(fontFamily: _arabicFont),
      headlineLarge:  base.headlineLarge?.copyWith(fontFamily: _arabicFont),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: _arabicFont),
      headlineSmall:  base.headlineSmall?.copyWith(fontFamily: _arabicFont),
      titleLarge:     base.titleLarge?.copyWith(fontFamily: _arabicFont, fontWeight: FontWeight.w700),
      titleMedium:    base.titleMedium?.copyWith(fontFamily: _arabicFont, fontWeight: FontWeight.w600),
      titleSmall:     base.titleSmall?.copyWith(fontFamily: _arabicFont, fontWeight: FontWeight.w600),
      bodyLarge:      base.bodyLarge?.copyWith(fontFamily: _arabicFont),
      bodyMedium:     base.bodyMedium?.copyWith(fontFamily: _arabicFont),
      bodySmall:      base.bodySmall?.copyWith(fontFamily: _arabicFont),
      labelLarge:     base.labelLarge?.copyWith(fontFamily: _arabicFont, fontWeight: FontWeight.w600),
      labelMedium:    base.labelMedium?.copyWith(fontFamily: _arabicFont),
      labelSmall:     base.labelSmall?.copyWith(fontFamily: _arabicFont),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _arabicFont,
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
    textTheme: _buildTextTheme(ThemeData.dark().textTheme),
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
      hintStyle: GoogleFonts.cairo(
        color: AppColors.textHint,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: AppColors.textSecondary,
      titleTextStyle: GoogleFonts.cairo(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: GoogleFonts.cairo(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
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
    fontFamily: _arabicFont,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      error: AppColors.accent,
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1D2E),
    ),
    textTheme: _buildTextTheme(ThemeData.light().textTheme),
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
      hintStyle: GoogleFonts.cairo(
        color: const Color(0xFF9E9E9E),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 0.5,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      titleTextStyle: GoogleFonts.cairo(
        color: const Color(0xFF1A1D2E),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: GoogleFonts.cairo(
        color: const Color(0xFF757575),
        fontSize: 13,
      ),
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
