import 'package:flutter/material.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

/// Reusable pill-shaped period navigator: a chevron-left button, a
/// centered label, and a chevron-right button, wrapped in a rounded
/// bordered pill — the "‹ July 2026 ›" pattern used system-wide.
class MonthNav extends StatelessWidget {
  const MonthNav({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: context.appTint,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _NavArrow(icon: AppIcons.chevronLeftRounded, onTap: onPrev),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        _NavArrow(icon: AppIcons.chevronRightRounded, onTap: onNext),
      ]),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconRef icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: AppIcon(
            icon,
            size: 18,
            color: enabled ? context.appSubtext : context.appSubtext.withAlpha(80),
          ),
        ),
      ),
    );
  }
}
