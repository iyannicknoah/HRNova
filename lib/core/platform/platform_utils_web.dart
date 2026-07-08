// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openInNewTab(String url) => html.window.open(url, '_blank');
