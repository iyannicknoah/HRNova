import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the app ships translations for.
const supportedAppLocales = [Locale('en'), Locale('fr')];

/// Persisted app language. Defaults to English; overridden at startup in
/// main() with the value saved in SharedPreferences (same pattern as theme).
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([Locale? initial]) : super(initial ?? const Locale('en'));

  Future<void> setLocale(Locale locale) async {
    if (!supportedAppLocales.contains(locale)) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
  }
}

final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
