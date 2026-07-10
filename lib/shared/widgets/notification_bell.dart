import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../features/leave/providers/leave_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../shared/widgets/app_icon.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return GestureDetector(
      onTap: () => _showPanel(context, ref),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.appTint,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            backgroundColor: AppColors.errorRed,
            child: AppIcon(AppIcons.notificationsRounded,
                size: 20, color: context.appText),
          ),
        ),
      ),
    );
  }

  void _showPanel(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      pageBuilder: (ctx, _, __) => Consumer(
        builder: (ctx, ref, _) {
          final items = ref.watch(notificationsStreamProvider).value ?? [];
          return Stack(
            children: [
              Positioned(
                left: 228,
                top: 56,
                width: 360,
                height: 500,
                child: _NotificationPanelCard(
                  items: items,
                  onRead: (id) {
                    ref.read(leaveNotifierProvider.notifier).markNotificationRead(id);
                  },
                  onReadAll: () {
                    ref.read(leaveNotifierProvider.notifier).markAllRead();
                  },
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationPanelCard extends StatelessWidget {
  const _NotificationPanelCard({
    required this.items,
    required this.onRead,
    required this.onReadAll,
    required this.onClose,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onRead;
  final VoidCallback onReadAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasUnread = items.any((n) => n['isRead'] != true);
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.darkBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(children: [
              const Text('Notifications',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (hasUnread)
                GestureDetector(
                  onTap: onReadAll,
                  child: const Text('Mark all read',
                      style: TextStyle(
                          color: AppColors.primaryBlue, fontSize: 14)),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onClose,
                child: const AppIcon(AppIcons.closeRounded,
                    size: 17, color: AppColors.textSecondary),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withAlpha(18)),
          // List
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.notificationsNoneRounded,
                            size: 40, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text('No notifications',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.white.withAlpha(10)),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      final id = n['id'] as String? ?? '';
                      final isUnread = n['isRead'] != true;
                      final type = n['type'] as String? ?? '';
                      return InkWell(
                        onTap: isUnread ? () => onRead(id) : null,
                        child: Container(
                          color: isUnread
                              ? AppColors.primaryBlue.withAlpha(22)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _iconBg(context, type),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: AppIcon(_iconFor(type),
                                    size: 15, color: _iconColor(type)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title'] as String? ?? '',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: isUnread
                                                ? FontWeight.w500
                                                : FontWeight.w400)),
                                    const SizedBox(height: 3),
                                    Text(n['body'] as String? ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13)),
                                    const SizedBox(height: 3),
                                    Text(_timeAgo(n['createdAt']),
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconRef _iconFor(String type) => switch (type) {
        'leave_request' => AppIcons.beachAccessRounded,
        'leave_approved' => AppIcons.checkCircleRounded,
        'leave_rejected' => AppIcons.cancelRounded,
        _ => AppIcons.notificationsRounded,
      };

  Color _iconBg(BuildContext context, String type) => switch (type) {
        'leave_request' => context.pillBlueBg,
        'leave_approved' => context.pillGreenBg,
        'leave_rejected' => context.pillRedBg,
        _ => context.pillNavyBg,
      };

  Color _iconColor(String type) => switch (type) {
        'leave_request' => AppColors.primaryBlue,
        'leave_approved' => AppColors.successGreen,
        'leave_rejected' => AppColors.errorRed,
        _ => AppColors.textSecondary,
      };

  String _timeAgo(dynamic ts) {
    DateTime? dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is String) {
      dt = DateTime.tryParse(ts);
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}
