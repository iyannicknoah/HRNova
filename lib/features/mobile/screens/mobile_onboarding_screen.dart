import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../l10n/tr.dart';

class MobileOnboardingScreen extends StatelessWidget {
  const MobileOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Stack(
        children: [
          // Faint full-bleed logo watermark
          Opacity(
            opacity: 0.3,
            child: Image.asset(
              context.isDark
                  ? 'assets/icon/icon_dark.png'
                  : 'assets/icon/icon_light.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Soft brand-tint wash, fading into the page background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.appTint, context.appBg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Welcome content, bottom-aligned
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      context.isDark
                          ? 'assets/icon/icon_dark.png'
                          : 'assets/icon/icon_light.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Welcome to HRNovva'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Check your attendance, request leave, and view your payslips — all from your phone.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  HRNovaButton(
                    label: context.tr('Signin'),
                    height: 55,
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
