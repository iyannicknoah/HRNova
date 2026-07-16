import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart' show appRouterProvider;
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode');
  final initialTheme = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final localeStr = prefs.getString('app_locale');
  final initialLocale = localeStr == 'fr' ? const Locale('fr') : const Locale('en');

  runApp(
    ProviderScope(
      overrides: [
        themeNotifierProvider
            .overrideWith((ref) => ThemeNotifier(initialTheme)),
        localeNotifierProvider
            .overrideWith((ref) => LocaleNotifier(initialLocale)),
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
    final locale = ref.watch(localeNotifierProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'HRNovva',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => child!,
    );
  }
}
