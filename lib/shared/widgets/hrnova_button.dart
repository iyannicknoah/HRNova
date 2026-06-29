import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HRNovaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final Color backgroundColor;
  final Color textColor;

  const HRNovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = false,
    this.backgroundColor = AppColors.primaryGreen,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );

    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      disabledBackgroundColor: backgroundColor.withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      minimumSize: const Size(64, 48), // Standardize 48px height
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Standardize 20px border radius
      ),
      elevation: 0,
    );

    final buttonWidget = ElevatedButton(
      onPressed: (isLoading || onPressed == null) ? null : onPressed,
      style: style,
      child: buttonContent,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
