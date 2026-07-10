import 'package:flutter/material.dart';
import '../../core/theme/theme_ext.dart';

/// Borderless, edge-anchored overlay matching the studied design language's
/// dialog pattern: `Dialog(elevation: 0, backgroundColor: transparent)`
/// anchored to a screen corner (or centered) instead of Material's default
/// centered `AlertDialog`, wrapping a bordered rounded content panel.
class AppDialogShell {
  AppDialogShell._();

  /// Shows [child] inside a bordered rounded panel anchored at [alignment]
  /// (defaults to top-right, matching the studied "Add" dialogs).
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Alignment alignment = Alignment.topRight,
    double maxWidth = 420,
    double radius = 20,
    EdgeInsets margin = const EdgeInsets.all(24),
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          alignment: alignment,
          child: GestureDetector(
            onTap: () {
              FocusScope.of(dialogContext).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Padding(
              padding: margin,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: dialogContext.appCard,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: dialogContext.accent4, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
