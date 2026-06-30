import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class JobBoardScreen extends StatelessWidget {
  const JobBoardScreen({super.key, required this.companySlug});

  final String companySlug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF0066CC)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppColors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('HRNova',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.cardBorder),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_outline_rounded, size: 56, color: AppColors.primaryBlue),
            const SizedBox(height: 20),
            const Text('Job Board',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Company: $companySlug',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Public Job Board — Part 10',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
