import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _urbanist(TextTheme base) {
    final t = GoogleFonts.urbanistTextTheme(base);
    // Slightly heavier default weights across the board
    return t.copyWith(
      displayLarge:  t.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall:  t.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium:t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge:    t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium:   t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:    t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge:     t.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium:    t.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall:     t.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge:    t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium:   t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall:    t.labelSmall?.copyWith(fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.backgroundBlue,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.successGreen,
        surface: AppColors.white,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSurface: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: AppColors.primaryBlue.withAlpha(20),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundBlue,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          minimumSize: const Size(0, 46),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 0.5),
    );
    return base.copyWith(textTheme: _urbanist(base.textTheme));
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.successGreen,
        surface: AppColors.darkCard,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSurface: AppColors.white.withAlpha(230),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.white.withAlpha(15), width: 0.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.white.withAlpha(30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.white.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          minimumSize: const Size(0, 46),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.white.withAlpha(20), thickness: 0.5),
    );
    return base.copyWith(textTheme: _urbanist(base.textTheme));
  }
}
