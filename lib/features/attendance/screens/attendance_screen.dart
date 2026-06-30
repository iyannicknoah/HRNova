import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Attendance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Attendance Management — Part 5', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
