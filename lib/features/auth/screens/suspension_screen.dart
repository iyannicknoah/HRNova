import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon.dart';

class SuspensionScreen extends ConsumerWidget {
  const SuspensionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'HR',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: context.appText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const TextSpan(
                          text: 'Nova',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Warning icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withAlpha(12),
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon(
                      AppIcons.blockRounded,
                      color: AppColors.errorRed,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    AppLocalizations.of(context).suspTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.appText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    AppLocalizations.of(context).suspBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appSubtext,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Support contact
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.appTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.alternate),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.mailOutlineRounded,
                            color: AppColors.primaryBlue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'support@hrnova.rw',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign out button
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: HRNovaButton(
                      label: AppLocalizations.of(context).suspSignOut,
                      onPressed: () =>
                          ref.read(authNotifierProvider.notifier).signOut(),
                      isFullWidth: true,
                      backgroundColor: AppColors.errorRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
