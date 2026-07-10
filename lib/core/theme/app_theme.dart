import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const _generalSans = 'General Sans';

  static TextTheme _generalSansTheme(TextTheme base) {
    final t = base.apply(fontFamily: _generalSans);
    return t.copyWith(
      displayLarge:  t.displayLarge?.copyWith(fontWeight: FontWeight.w600),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w600),
      displaySmall:  t.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium:t.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge:    t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium:   t.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      titleSmall:    t.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge:     t.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium:    t.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall:     t.bodySmall?.copyWith(fontWeight: FontWeight.w400),
      labelLarge:    t.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelMedium:   t.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall:    t.labelSmall?.copyWith(fontWeight: FontWeight.w400),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.white,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
    return base.copyWith(textTheme: _generalSansTheme(base.textTheme));
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
        surface: AppColors.darkBackground,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSurface: AppColors.white.withAlpha(230),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
        fillColor: AppColors.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.white.withAlpha(30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.white.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
    return base.copyWith(textTheme: _generalSansTheme(base.textTheme));
  }
}
