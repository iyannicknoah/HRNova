import 'package:flutter/material.dart';
import '../../core/theme/theme_ext.dart';
import '../../l10n/tr.dart';

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
    final colors = _colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        context.tr(_capitalize(text)),
        style: TextStyle(
          color: colors.$2,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.0,
        ),
      ),
    );
  }

  (Color, Color) _colors(BuildContext context) {
    return switch (type) {
      StatusType.success => (context.pillGreenBg, context.pillGreenText),
      StatusType.warning => (context.pillAmberBg, context.pillAmberText),
      StatusType.error => (context.pillRedBg, context.pillRedText),
      StatusType.info => (context.pillBlueBg, context.pillBlueText),
      StatusType.neutral => (context.pillNavyBg, context.pillNavyText),
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}
