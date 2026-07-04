import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum StatusType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
  });

  final String text;
  final StatusType type;

  factory StatusBadge.fromString(String status) {
    final lower = status.toLowerCase();
    StatusType type;
    if (['active', 'approved', 'present', 'paid', 'completed', 'hired'].contains(lower)) {
      type = StatusType.success;
    } else if (['pending', 'under review', 'in progress', 'processing'].contains(lower)) {
      type = StatusType.warning;
    } else if (['inactive', 'rejected', 'absent', 'suspended', 'terminated', 'failed']
        .contains(lower)) {
      type = StatusType.error;
    } else if (['on leave', 'shortlisted', 'interview', 'partial'].contains(lower)) {
      type = StatusType.info;
    } else {
      type = StatusType.neutral;
    }
    return StatusBadge(text: status, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _capitalize(text),
        style: TextStyle(
          color: colors.$2,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    return switch (type) {
      StatusType.success => (AppColors.pillGreenBg, AppColors.pillGreenText),
      StatusType.warning => (AppColors.pillAmberBg, AppColors.pillAmberText),
      StatusType.error => (AppColors.pillRedBg, AppColors.pillRedText),
      StatusType.info => (AppColors.pillBlueBg, AppColors.pillBlueText),
      StatusType.neutral => (AppColors.pillNavyBg, AppColors.pillNavyText),
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}
