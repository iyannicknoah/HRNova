import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';

class RecruitmentScreen extends StatelessWidget {
  const RecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_rounded, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text('Recruitment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText)),
            const SizedBox(height: 8),
            Text('Recruitment Panel — Part 10', style: TextStyle(color: context.appSubtext)),
          ],
        ),
      ),
    );
  }
}
