import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../l10n/tr.dart';

class ApplicationSuccessScreen extends StatelessWidget {
  const ApplicationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF2979E0)]),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const AppIcon(AppIcons.boltRounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('HRNovva',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.cardBorder),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(AppIcons.checkCircleRounded,
                      color: AppColors.successGreen, size: 48),
                ),
                const SizedBox(height: 24),

                Text(context.tr('Application Submitted!'),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),

                Text(
                  context.tr('Thank you for applying. We have received your application and will be in touch soon.\n\nPlease check your email for a confirmation.'),
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.primaryBlue.withAlpha(25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('What happens next?'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue)),
                      const SizedBox(height: 12),
                      _Step(number: '1', text: context.tr('Our team reviews your application')),
                      _Step(number: '2', text: context.tr('Shortlisted candidates are contacted for an interview')),
                      _Step(number: '3', text: context.tr('Final decision is communicated by email')),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                HRNovaButton(
                  label: context.tr('Back to Job Board'),
                  outlined: true,
                  isFullWidth: false,
                  textColor: AppColors.textSecondary,
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
