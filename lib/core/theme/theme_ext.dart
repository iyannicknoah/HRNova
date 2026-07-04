import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Page / scaffold background
  Color get appBg =>
      isDark ? AppColors.darkBackground : AppColors.backgroundBlue;

  // Card / panel / dialog background
  Color get appCard => isDark ? AppColors.darkCard : Colors.white;

  // Input field fill
  Color get appField =>
      isDark ? const Color(0xFF0A1628) : AppColors.lightBlue50;

  // Header / tab bar background (slightly lighter than card)
  Color get appHeader =>
      isDark ? const Color(0xFF0D1E35) : Colors.white;

  // Subtle section tint (filter bar, table header fill, etc.)
  Color get appTint =>
      isDark ? const Color(0xFF0A1628) : AppColors.lightBlue50;

  // Divider / border
  Color get appBorder =>
      isDark ? const Color(0xFF1A2D48) : AppColors.cardBorder;

  // Primary text
  Color get appText =>
      isDark ? Colors.white : AppColors.textPrimary;

  // Secondary / muted text
  Color get appSubtext =>
      isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;

  // Shadow-only card decoration — no border, matches super admin style
  BoxDecoration cardDeco([double radius = 14]) => BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(55) : Colors.black.withAlpha(14),
            blurRadius: isDark ? 16 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
