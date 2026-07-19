import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart' show appRouterProvider;
import 'core/theme/app_theme.dart';
import 'core/utils/web_reload_stub.dart'
    if (dart.library.html) 'core/utils/web_reload_web.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global crash safety net: any widget build exception, anywhere in the
  // app, previously rendered as a blank white page with no way to recover
  // short of a manual URL reload. Show a visible error + reload button
  // instead. This does not fix underlying bugs — it makes them survivable.
  ErrorWidget.builder = (details) {
    debugPrint('[ErrorWidget] ${details.exceptionAsString()}');
    return Material(
      color: const Color(0xFF0F1215),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE5534B), size: 44),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong on this page.',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Reload to continue — your data is safe.',
                style: TextStyle(color: Color(0xFF8A9BBC), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: reloadPage,
                  child: const Text('Reload'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

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
