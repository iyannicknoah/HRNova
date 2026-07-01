import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool outlined;

  static const _radius = 100.0;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryBlue;
    final fg = textColor ?? AppColors.white;
    final disabled = onPressed == null || isLoading;

    if (outlined) {
      return SizedBox(
        height: 48,
        width: isFullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: bg, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius)),
            foregroundColor: bg,
          ),
          child: _buildChild(bg),
        ),
      );
    }

    return SizedBox(
      height: 48,
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
            minimumSize: Size(isFullWidth ? double.infinity : 0, 48),
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
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      );
    }
    return Text(label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
  }
}
