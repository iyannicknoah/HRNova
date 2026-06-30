import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HRNovaCard extends StatelessWidget {
  const HRNovaCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 20,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.white;
    final border = borderColor ?? AppColors.cardBorder;

    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.5),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withAlpha(12),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
