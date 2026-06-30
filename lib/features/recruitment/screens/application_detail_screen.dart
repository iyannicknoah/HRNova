import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ApplicationDetailScreen extends StatelessWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.jobId,
    required this.applicationId,
  });

  final String jobId;
  final String applicationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      appBar: AppBar(title: const Text('Application Detail')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_rounded, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            const Text('Application Detail', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('App: $applicationId', style: const TextStyle(color: AppColors.textSecondary)),
            const Text('Recruitment — Part 10', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
