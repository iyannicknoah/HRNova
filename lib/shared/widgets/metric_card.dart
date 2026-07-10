import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import 'hrnova_card.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive,
    this.onTap,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? trend;
  final bool? trendPositive;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return HRNovaCard(
      padding: const EdgeInsets.all(20),
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: context.appSubtext,
                  letterSpacing: 0.0,
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trendPositive ?? true)
                        ? context.pillGreenBg
                        : context.pillRedBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        (trendPositive ?? true)
                            ? AppIcons.arrowUpwardRounded
                            : AppIcons.arrowDownwardRounded,
                        size: 12,
                        color: (trendPositive ?? true)
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: (trendPositive ?? true)
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: context.appText,
              letterSpacing: 0.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: context.appSubtext,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
