import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_rounded, size: 48, color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Payroll', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Payroll — Part 7', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
