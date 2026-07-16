import 'package:flutter/widgets.dart';
import 'fr_dictionary.dart';

/// Lightweight gettext-style translation: the English string in code is the
/// key; French comes from [frDictionary]. Unknown strings fall back to
/// English, so a missing entry can never break the UI.
///
/// The generated AppLocalizations (ARB) remains the source for the app shell
/// (sidebar, login, language switcher); screens use this for their bulk of
/// strings.
extension Tr on BuildContext {
  bool get isFr => Localizations.localeOf(this).languageCode == 'fr';

  String tr(String english) =>
      isFr ? (frDictionary[english] ?? english) : english;

  /// Translate a template containing `{placeholders}` then substitute them.
  /// Example: `context.trp('Sent {sent} of {total}', {'sent': '3', 'total': '7'})`
  String trp(String english, Map<String, String> params) {
    var s = tr(english);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}
