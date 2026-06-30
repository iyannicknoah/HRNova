import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class JobPostingScreen extends StatelessWidget {
  const JobPostingScreen({super.key, this.jobId});

  final String? jobId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      appBar: AppBar(title: Text(jobId == null ? 'New Job Posting' : 'Edit Job Posting')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.post_add_rounded, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text(jobId == null ? 'Create Job Posting' : 'Job: $jobId',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Recruitment — Part 10', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
