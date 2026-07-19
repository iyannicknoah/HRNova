import 'dart:html' as html;

/// Reloads the browser page — the recovery action for the global crash
/// safety net in main.dart. Only compiled in on web (see web_reload_stub.dart
/// for the mobile no-op, selected via conditional import).
void reloadPage() => html.window.location.reload();
