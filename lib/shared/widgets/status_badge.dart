import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final String type;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type.toLowerCase()) {
      case 'active':
      case 'ontime':
      case 'approved':
        bg = AppColors.pillGreenBg;
        fg = AppColors.pillGreenText;
        break;
      case 'pending':
      case 'late':
        bg = AppColors.pillAmberBg;
        fg = AppColors.pillAmberText;
        break;
      case 'suspended':
      case 'absent':
      case 'rejected':
        bg = AppColors.pillRedBg;
        fg = AppColors.pillRedText;
        break;
      case 'info':
      case 'leave':
      default:
        bg = AppColors.pillBlueBg;
        fg = AppColors.pillBlueText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
