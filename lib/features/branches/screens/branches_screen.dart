import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Branches', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Branch Management — Part 13', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
