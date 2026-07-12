import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

class HRNovaButton extends StatelessWidget {
  const HRNovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.outlined = false,
    this.isTextButton = false,
    this.height = 48,
    this.borderWidth = 1.5,
  });

  /// Transparent, underlined text-only button — matches the studied
  /// design's "Forgot password?" / "Sign up" secondary actions.
  const HRNovaButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor,
    this.height = 30,
  })  : isLoading = false,
        isFullWidth = false,
        backgroundColor = null,
        icon = null,
        outlined = false,
        isTextButton = true,
        borderWidth = 1.5;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final IconRef? icon;
  final bool outlined;
  final bool isTextButton;
  final double height;
  final double borderWidth;

  static const _radius = 30.0;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryBlue;
    final fg = textColor ?? AppColors.white;
    final disabled = onPressed == null || isLoading;

    if (isTextButton) {
      final color = textColor ?? AppColors.textPrimary;
      return SizedBox(
        height: height,
        child: TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: isLoading
              ? _buildChild(color)
              : Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: color,
                    decoration: TextDecoration.underline,
                  ),
                ),
        ),
      );
    }

    if (outlined) {
      final outlineColor = textColor ?? bg;
      return SizedBox(
        height: height,
        width: isFullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: outlineColor, width: borderWidth),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius)),
            foregroundColor: outlineColor,
          ),
          child: _buildChild(outlineColor),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: disabled ? AppColors.textSecondary.withAlpha(80) : AppColors.primaryBlue,
        ),
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: fg,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius)),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: _buildChild(fg),
        ),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon!, size: 17),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      );
    }
    return Text(label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15));
  }
}
