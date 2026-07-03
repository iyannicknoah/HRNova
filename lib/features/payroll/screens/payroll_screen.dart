import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text('Payroll', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 8),
            Text('Payroll — Part 7', style: TextStyle(color: context.appSubtext)),
          ],
        ),
      ),
    );
  }
}
