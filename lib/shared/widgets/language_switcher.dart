import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_icon.dart';

/// Circular flag button shown on the top bar of every page. Shows the flag
/// of the current language; tapping opens a dropdown with the available
/// languages. Flags are painted (not emoji) so they render on all platforms.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<Locale>(
      tooltip: l10n.language,
      offset: Offset(0, size + 8),
      color: context.appCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.appBorder),
      ),
      onSelected: (l) => ref.read(localeNotifierProvider.notifier).setLocale(l),
      itemBuilder: (ctx) => [
        _item(ctx, const Locale('en'), l10n.languageEnglish, locale),
        _item(ctx, const Locale('fr'), l10n.languageFrench, locale),
      ],
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.appBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(child: _FlagIcon(locale.languageCode)),
      ),
    );
  }

  PopupMenuItem<Locale> _item(
      BuildContext context, Locale l, String label, Locale current) {
    final selected = l.languageCode == current.languageCode;
    return PopupMenuItem<Locale>(
      value: l,
      child: Row(children: [
        SizedBox(
          width: 22,
          height: 22,
          child: ClipOval(child: _FlagIcon(l.languageCode)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                color: selected ? AppColors.primaryBlue : context.appText,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
        if (selected)
          const AppIcon(AppIcons.checkRounded, size: 16, color: AppColors.primaryBlue),
      ]),
    );
  }
}

class _FlagIcon extends StatelessWidget {
  const _FlagIcon(this.languageCode);
  final String languageCode;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: languageCode == 'fr' ? _FrenchFlagPainter() : _UkFlagPainter(),
        size: Size.infinite,
      );
}

/// French tricolore — three vertical bands.
class _FrenchFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height),
        Paint()..color = const Color(0xFF0055A4));
    canvas.drawRect(Rect.fromLTWH(w, 0, w, size.height),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w * 2, 0, w, size.height),
        Paint()..color = const Color(0xFFEF4135));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Union Jack, simplified for small circular rendering.
class _UkFlagPainter extends CustomPainter {
  static const _blue = Color(0xFF012169);
  static const _red = Color(0xFFC8102E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Field
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _blue);

    // White diagonals (St Andrew)
    final whiteDiag = Paint()
      ..color = Colors.white
      ..strokeWidth = h / 3.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(w, h), whiteDiag);
    canvas.drawLine(Offset(w, 0), Offset(0, h), whiteDiag);

    // Red diagonals (St Patrick)
    final redDiag = Paint()
      ..color = _red
      ..strokeWidth = h / 9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(w, h), redDiag);
    canvas.drawLine(Offset(w, 0), Offset(0, h), redDiag);

    // White cross (St George border)
    final whiteCross = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(w / 2 - w / 6, 0, w / 3, h), whiteCross);
    canvas.drawRect(
        Rect.fromLTWH(0, h / 2 - h / 6, w, h / 3), whiteCross);

    // Red cross (St George)
    final redCross = Paint()..color = _red;
    canvas.drawRect(
        Rect.fromLTWH(w / 2 - w / 10, 0, w / 5, h), redCross);
    canvas.drawRect(
        Rect.fromLTWH(0, h / 2 - h / 10, w, h / 5), redCross);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
