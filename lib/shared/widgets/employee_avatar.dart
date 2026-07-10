import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.showRing = false,
    this.ringColor,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final bool showRing;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final gradients = AppColors.gradientForName(name);

    Widget avatar;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _gradientAvatar(initials, gradients),
        ),
      );
    } else {
      avatar = _gradientAvatar(initials, gradients);
    }

    if (showRing) {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor ?? AppColors.primaryBlue,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: avatar,
        ),
      );
    }
    return avatar;
  }

  Widget _gradientAvatar(String initials, List<Color> gradients) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}
