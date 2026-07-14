import 'package:flutter/widgets.dart';
import 'package:heroicons/heroicons.dart';
import '../../core/theme/app_icons.dart';

/// Renders an [IconRef]. Drop-in replacement for the Material [Icon] widget.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.ref, {
    super.key,
    this.size,
    this.color,
  });

  final IconRef ref;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return HeroIcon(
      ref.hero,
      style: HeroIconStyle.solid,
      size: size,
      color: color,
    );
  }
}
