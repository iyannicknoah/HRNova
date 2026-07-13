import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

class HRNovaTextField extends StatelessWidget {
  const HRNovaTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.initialValue,
    this.errorText,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final IconRef? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? initialValue;
  final String? errorText;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(
            fontSize: 16,
            color: context.appText,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            hintStyle: TextStyle(
                color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w300),
            prefixIcon: prefixIcon != null
                ? AppIcon(prefixIcon!, color: context.appSubtext, size: 20)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? context.appCard : context.appTint,
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
