import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hrnova_button.dart';
import '../../../../shared/widgets/hrnova_logo.dart';
import '../providers/auth_provider.dart';

class SuspensionScreen extends ConsumerWidget {
  const SuspensionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(
        children: [
          // Background ambient gradient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.errorRed.withOpacity(0.15),
                    const Color(0x00A32D2D),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardNavy.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Title
                    const HRNovaLogo(size: 28),
                    const SizedBox(height: 32),

                    // Red Warning Icon with glow
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.errorRed.withOpacity(0.1),
                        border: Border.all(color: AppColors.errorRed.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.errorRed,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Account Suspended',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Body
                    const Text(
                      'Your company account has been suspended.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please contact support to reactivate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Contact
                    const Text(
                      'Contact: support@hrnova.rw',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightGreen,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: Color(0x13FFFFFF), height: 1),
                    const SizedBox(height: 24),

                    // Sign Out Button
                    HRNovaButton(
                      label: 'Sign Out',
                      onPressed: () async {
                        await ref.read(authNotifierProvider.notifier).signOut();
                      },
                      fullWidth: true,
                      backgroundColor: const Color(0x1AFFFFFF),
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
