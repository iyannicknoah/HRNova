import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ApplicationSuccessScreen extends StatelessWidget {
  const ApplicationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.successGreen),
            ),
            const SizedBox(height: 24),
            const Text('Application Submitted!',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text("We'll be in touch soon.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Application Success — Part 10',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
