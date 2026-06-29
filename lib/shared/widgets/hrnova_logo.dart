import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HRNovaLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? iconColor;
  final Color? textColor;

  const HRNovaLogo({
    super.key,
    this.size = 28,
    this.showText = true,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Geometric Gradient Logo Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                iconColor ?? AppColors.lightGreen,
                iconColor?.withOpacity(0.8) ?? AppColors.primaryGreen,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (iconColor ?? AppColors.lightGreen).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.bubble_chart_rounded, // Premium tech icon representing connection
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.4),
          Text(
            'HRNova',
            style: TextStyle(
              fontSize: size * 0.9,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: textColor ?? Colors.white,
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: size * 0.1, top: size * 0.5),
            width: size * 0.18,
            height: size * 0.18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor ?? AppColors.lightGreen,
            ),
          ),
        ],
      ],
    );
  }
}
