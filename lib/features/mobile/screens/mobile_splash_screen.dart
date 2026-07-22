import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart' show homeForRole;
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';

/// How long the brand animation stays up before navigating, so a fast
/// session restore doesn't make the splash flicker past.
const _minSplash = Duration(milliseconds: 2200);

/// Cap on waiting for Firebase — offline, these can hang indefinitely and
/// the app must still get past the splash.
const _authTimeout = Duration(seconds: 6);

class MobileSplashScreen extends ConsumerStatefulWidget {
  const MobileSplashScreen({super.key});

  @override
  ConsumerState<MobileSplashScreen> createState() => _MobileSplashScreenState();
}

class _MobileSplashScreenState extends ConsumerState<MobileSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.27, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _resumeSession();
  }

  /// Firebase restores a previous sign-in from device storage on startup, so
  /// a returning user should land back in the app rather than on the sign-in
  /// screen. Wait for that restore to settle, then route by role.
  Future<void> _resumeSession() async {
    final minSplash = Future<void>.delayed(_minSplash);

    User? user;
    try {
      user = await ref.read(authStateProvider.future).timeout(_authTimeout);
    } catch (_) {
      // Stream error or timeout — fall back to whatever Firebase already
      // restored synchronously.
      user = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    String destination;
    if (user == null) {
      destination = '/mobile-onboarding';
    } else {
      try {
        final claims =
            await ref.read(userClaimsProvider.future).timeout(_authTimeout);
        destination = homeForRole(claims?['role'] as String?);
      } catch (_) {
        // Signed in but claims unreachable (e.g. offline). Keep the session
        // and land on the mobile home; the router re-routes by role once the
        // claims resolve.
        destination = '/mobile-home';
      }
    }

    await minSplash;
    if (!mounted) return;
    context.go(destination);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF60AAFF), AppColors.primaryBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
