import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Leave Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Leave Management — Part 6', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
