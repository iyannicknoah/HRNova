import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// A single entry in a [RowActionsMenu] popup.
class RowAction {
  const RowAction({required this.label, required this.icon, required this.onTap, this.danger = false});
  final String label;
  final IconRef icon;
  final VoidCallback onTap;
  final bool danger;
}

/// A single "···" button that opens a floating popup listing [actions] —
/// the shared replacement for a row of separate icon buttons in table rows.
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({super.key, required this.actions});
  final List<RowAction> actions;

  Future<void> _show(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final size = renderBox.size;

    final action = await showMenu<RowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 140, offset.dy + size.height + 4,
        offset.dx + size.width, offset.dy + size.height + 300,
      ),
      color: context.appCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder),
      ),
      items: [
        for (final a in actions)
          PopupMenuItem<RowAction>(
            value: a,
            height: 40,
            child: Row(children: [
              AppIcon(a.icon, size: 16, color: a.danger ? AppColors.errorRed : context.appSubtext),
              const SizedBox(width: 10),
              Text(a.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: a.danger ? AppColors.errorRed : context.appText)),
            ]),
          ),
      ],
    );
    action?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => InkWell(
        onTap: () => _show(ctx),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: AppIcon(AppIcons.moreHorizRounded, size: 18, color: context.appSubtext),
        ),
      ),
    );
  }
}
