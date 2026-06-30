import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NovaAiScreen extends StatelessWidget {
  const NovaAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Nova AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('AI Assistant — Part 9', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
