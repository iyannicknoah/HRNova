import 'package:flutter/material.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/theme/app_spacing.dart';

/// Reusable table header row: `Expanded` label cells in `secondaryText`,
/// bracketed by hairline `alternate`-colored dividers — the Row+Divider
/// table pattern used throughout the studied design language.
class AppTableHeader extends StatelessWidget {
  const AppTableHeader({
    super.key,
    required this.columns,
    this.flex,
  });

  /// Column labels, left to right.
  final List<String> columns;

  /// Optional flex weight per column (defaults to 1 for every column).
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: context.alternate),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.l),
                Expanded(
                  flex: flex != null && i < flex!.length ? flex![i] : 1,
                  child: Text(
                    columns[i],
                    style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.alternate),
      ],
    );
  }
}
