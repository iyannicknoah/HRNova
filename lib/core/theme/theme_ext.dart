import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Page / scaffold background — Flexra "primaryBackground" token.
  // Containers and pages share the same primary background value in both
  // themes, so there's no separate page/container tier.
  Color get appBg =>
      isDark ? AppColors.darkBackground : Colors.white;

  // Card / panel / dialog background — same primary value as [appBg].
  Color get appCard => isDark ? AppColors.darkBackground : Colors.white;

  // Input field fill — recessed into the page background in dark mode.
  Color get appField =>
      isDark ? AppColors.darkCard : AppColors.lightBlue50;

  // Header / tab bar background (same surface as cards)
  Color get appHeader => isDark ? AppColors.darkBackground : Colors.white;

  // Subtle section tint (filter bar, table header fill, etc.) — a touch
  // lighter than the card surface so it reads as a highlight, not a hole.
  Color get appTint => isDark
      ? Color.alphaBlend(Colors.white.withAlpha(12), AppColors.darkBackground)
      : AppColors.lightBlue50;

  // Divider / border — Flexra "alternate" token
  Color get appBorder => isDark
      ? Color.alphaBlend(Colors.white.withAlpha(18), AppColors.darkBackground)
      : AppColors.cardBorder;

  // Primary text — Flexra "primaryText" token
  Color get appText =>
      isDark ? Colors.white : AppColors.textPrimary;

  // Secondary / muted text — Flexra "secondaryText" token
  Color get appSubtext =>
      isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;

  // ── Flexra token-role aliases ──────────────────────────────────────────
  // These re-home HRNovva's existing brand colors under the role names used
  // by the studied design language, so components can be written the same
  // way the source screens were — without changing any actual hex value.

  /// Hairline borders / dividers / unfocished input border. Same value as
  /// [appBorder]; kept as a separate name because Flexra's "alternate" and
  /// "accent4" roles are distinct concepts even though HRNovva uses one hue
  /// for both today.
  Color get alternate => appBorder;

  /// Bordered stat-card / panel border color.
  Color get accent4 => appBorder;

  /// Brand action color — buttons, focused input border, tab indicator,
  /// FAB fill. Maps to HRNovva's existing primary blue.
  Color get tertiary => AppColors.primaryBlue;

  /// Text/icon color on top of a tertiary-filled surface (e.g. button
  /// labels). HRNovva's buttons already use white-on-blue.
  Color get accent3 => AppColors.white;

  /// First chart series / small accent color.
  Color get chartPrimary => AppColors.primaryBlue;

  /// Second chart series.
  Color get chartSecondary => AppColors.successGreen;

  // Flat bordered card decoration — Flexra cards use a hairline border
  // instead of a drop shadow. Radius 18 matches the studied stat-card shape.
  BoxDecoration cardDeco([double radius = 18]) => BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent4, width: 1),
      );

  // ── Theme-aware tint pairs ──────────────────────────────────────────────
  // Used for icon-container backgrounds and status/type badges. In light
  // mode these are the original pale tints; in dark mode they're a low-alpha
  // wash of the same hue over the card surface, so nothing renders as a
  // flat white/pale box against a dark page.
  Color _tintBg(Color hue) => isDark
      ? Color.alphaBlend(hue.withAlpha(36), AppColors.darkBackground)
      : Color.alphaBlend(hue.withAlpha(28), Colors.white);

  Color get pillGreenBg => isDark ? _tintBg(AppColors.successGreen) : AppColors.pillGreenBg;
  Color get pillGreenText => AppColors.successGreen;

  Color get pillAmberBg => isDark ? _tintBg(AppColors.warningAmber) : AppColors.pillAmberBg;
  Color get pillAmberText => AppColors.warningAmber;

  Color get pillRedBg => isDark ? _tintBg(AppColors.errorRed) : AppColors.pillRedBg;
  Color get pillRedText => AppColors.errorRed;

  Color get pillBlueBg => isDark ? _tintBg(AppColors.primaryBlue) : AppColors.pillBlueBg;
  Color get pillBlueText => AppColors.primaryBlue;

  Color get pillNavyBg => isDark ? _tintBg(appSubtext) : AppColors.pillNavyBg;
  Color get pillNavyText => appSubtext;
}
