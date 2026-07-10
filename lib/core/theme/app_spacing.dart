import 'package:flutter/material.dart';

/// Spacing scale distilled from the studied Flexra design language, where
/// gaps between elements are expressed via `.divide(SizedBox(...))` rather
/// than ad-hoc padding numbers. Use these constants instead of picking a new
/// arbitrary value each time.
class AppSpacing {
  AppSpacing._();

  static const double xs = 5;
  static const double sm = 8;
  static const double s = 10;
  static const double m = 15;
  static const double l = 20;
  static const double section = 40;
  static const double columnGap = 60;

  /// Standard horizontal page padding used across every top-level screen.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 40);
}

/// Mirrors the studied design language's `.divide(SizedBox(...))` pattern:
/// inserts [separator] between each child instead of hand-placing gaps.
extension WidgetListDivideX on List<Widget> {
  List<Widget> divide(Widget separator) {
    if (isEmpty) return this;
    final result = <Widget>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) result.add(separator);
      result.add(this[i]);
    }
    return result;
  }
}
