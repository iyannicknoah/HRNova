import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HRNovaTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const HRNovaTextField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.controller,
    this.suffixIcon,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.darkNavy.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.darkNavy,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            errorText: errorText,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0x3BFFFFFF) : AppColors.darkNavy.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0x1BFFFFFF) : AppColors.darkNavy.withOpacity(0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.errorRed,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.errorRed,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
