import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// Visual sibling of [HRNovaTextField] used for dropdown/select fields.
///
/// Matches the login-screen field design (label above, 16px radius, visible
/// border in all states, blue focus border) but — deliberately — has no
/// fill color, only a border, so dropdowns read distinctly from filled text
/// inputs.
class HRNovaDropdown<T> extends StatelessWidget {
  const HRNovaDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.validator,
    this.showLabel = true,
    this.isExpanded = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;
  final String? Function(T?)? validator;
  final bool showLabel;
  /// When false, the dropdown sizes to fit its content instead of
  /// stretching to fill the available width.
  final bool isExpanded;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.appText,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          isExpanded: isExpanded,
          icon: AppIcon(AppIcons.keyboardArrowDown, color: context.appSubtext, size: 18),
          style: TextStyle(
            fontSize: 16,
            color: context.appText,
            fontWeight: FontWeight.w400,
          ),
          dropdownColor: context.appCard,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w300),
            filled: false,
            contentPadding:
                const EdgeInsetsDirectional.fromSTEB(14, 15, 15, 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide: BorderSide(color: context.appBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide: BorderSide(color: context.appBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide:
                  const BorderSide(color: AppColors.primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide:
                  const BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_radius),
              borderSide: BorderSide(color: context.appBorder),
            ),
          ),
        ),
      ],
    );
  }
}
