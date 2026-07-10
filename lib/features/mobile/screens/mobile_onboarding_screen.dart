import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

class MobileOnboardingScreen extends StatelessWidget {
  const MobileOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildBrand(context),
              const SizedBox(height: 52),
              _buildRoleHeader(context),
              const SizedBox(height: 20),
              _RoleCard(
                icon: AppIcons.badgeRounded,
                title: 'Employee',
                subtitle: 'Payslips, leave requests\nand attendance tracking',
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.go('/login'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: AppIcons.qrCodeScannerRounded,
                title: 'Guard / Reception',
                subtitle: 'Scan employee QR codes\nto record attendance',
                gradient: const LinearGradient(
                  colors: [Color(0xFF1DB87A), Color(0xFF0E9160)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                iconShadowColor: Color(0xFF1DB87A),
                onTap: () => context.go('/guard-login'),
              ),
              const Spacer(flex: 3),
              Text(
                'v1.0.0 · HRNovva Rwanda',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.35),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const AppIcon(AppIcons.peopleRounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 20),
        Text(
          'HRNovva',
          style: TextStyle(
            color: context.appText,
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Smart HR for Modern Rwanda',
          style: TextStyle(color: context.appSubtext, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildRoleHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          'How are you using HRNovva?',
          style: TextStyle(
            color: context.appText,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Select your role to continue',
          style: TextStyle(color: context.appSubtext, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.iconShadowColor,
  });

  final IconRef icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final Color? iconShadowColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: context.cardDeco(),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (iconShadowColor ?? AppColors.primaryBlue).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AppIcon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(
                AppIcons.arrowForwardIosRounded,
                color: AppColors.primaryBlue,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
