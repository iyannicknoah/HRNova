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
///
/// Deliberately built on a raw [OverlayEntry] instead of [showMenu]/
/// [PopupMenuButton]. Those push an animated [PopupRoute] onto the
/// Navigator; selecting an item that itself opens a follow-up dialog (e.g.
/// a delete confirmation) means pushing a second route while the first is
/// still mid-way through its exit transition — a known source of Flutter
/// Element-tree corruption ("_elements.contains(element) is not true").
/// An [OverlayEntry] has no route, no transition, and no Navigator
/// bookkeeping — insert/remove are synchronous, so there's no window for
/// that race to occur.
class RowActionsMenu extends StatefulWidget {
  const RowActionsMenu({super.key, required this.actions});
  final List<RowAction> actions;

  @override
  State<RowActionsMenu> createState() => _RowActionsMenuState();
}

class _RowActionsMenuState extends State<RowActionsMenu> {
  final _buttonKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(context);
    if (renderBox == null || overlayState == null) return;
    final overlayBox = overlayState.context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final buttonSize = renderBox.size;
    final overlaySize = overlayBox.size;

    const menuWidth = 190.0;
    var left = buttonOffset.dx + buttonSize.width - menuWidth;
    left = left.clamp(8.0, overlaySize.width - menuWidth - 8.0);
    final top = buttonOffset.dy + buttonSize.height + 4;

    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Transparent full-screen barrier — tapping outside the menu closes it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: overlayContext.appCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: overlayContext.appBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in widget.actions)
                      InkWell(
                        onTap: () => _select(a),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            AppIcon(a.icon, size: 16, color: a.danger ? AppColors.errorRed : overlayContext.appSubtext),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(a.label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: a.danger ? AppColors.errorRed : overlayContext.appText)),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlayState.insert(_entry!);
    setState(() {});
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _select(RowAction action) {
    _closeMenu();
    // The overlay entry above is already gone by the time this runs (remove()
    // is synchronous), so it's safe to trigger a follow-up dialog immediately
    // — there's no route/transition left to race with.
    action.onTap();
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _buttonKey,
      onTap: _toggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: AppIcon(AppIcons.moreHorizRounded, size: 18, color: context.appSubtext),
      ),
    );
  }
}
