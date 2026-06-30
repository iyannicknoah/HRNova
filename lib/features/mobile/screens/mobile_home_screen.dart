import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Employee App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Mobile Home — Part 12', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
