import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../l10n/tr.dart';
import 'app_dialog_shell.dart';
import 'hrnova_button.dart';

/// Shows a centered confirm/cancel dialog. Returns true if confirmed,
/// false if cancelled or dismissed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final result = await AppDialogShell.show<bool>(
    context: context,
    alignment: Alignment.center,
    maxWidth: 360,
    child: Builder(
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: ctx.appText)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(fontSize: 15, color: ctx.appSubtext, height: 1.4)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: HRNovaButton(
                  label: ctx.tr(cancelLabel),
                  outlined: true,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HRNovaButton(
                  label: ctx.tr(confirmLabel),
                  backgroundColor: danger ? AppColors.errorRed : null,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
