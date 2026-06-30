import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Performance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Performance Management — Part 8', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
