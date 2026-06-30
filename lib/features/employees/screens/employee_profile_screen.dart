import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class EmployeeProfileScreen extends StatelessWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      appBar: AppBar(title: const Text('Employee Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            const Text('Employee Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('ID: $employeeId', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('Employee Profile — Part 4', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
