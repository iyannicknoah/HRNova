import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart' show appRouterProvider;
import 'core/providers/ui_providers.dart' show mobileOnboardingSeenProvider;
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Load persisted preferences before first frame
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode');
  final initialTheme = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final mobileOnboardingSeen = prefs.getBool('mobile_onboarding_seen') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        themeNotifierProvider
            .overrideWith((ref) => ThemeNotifier(initialTheme)),
        mobileOnboardingSeenProvider.overrideWith((ref) => mobileOnboardingSeen),
      ],
      child: const HRNovaApp(),
    ),
  );
}

class HRNovaApp extends ConsumerWidget {
  const HRNovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'HRNova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // Global text size increase — affects every TextStyle in the whole app
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.1),
        ),
        child: child!,
      ),
    );
  }
}
