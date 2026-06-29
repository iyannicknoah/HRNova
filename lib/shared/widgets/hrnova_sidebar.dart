import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'hrnova_logo.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final int? badgeCount;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.badgeCount,
  });
}

class HRNovaSidebar extends StatelessWidget {
  final String currentRoute;
  final String companyName;
  final String userName;
  final String userRole;
  final ValueChanged<String> onItemTapped;
  final List<SidebarItem>? customItems;

  const HRNovaSidebar({
    super.key,
    required this.currentRoute,
    required this.companyName,
    required this.userName,
    required this.userRole,
    required this.onItemTapped,
    this.customItems,
  });

  @override
  Widget build(BuildContext context) {
    // Default list of items if not provided
    final items = customItems ?? const [
      SidebarItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      SidebarItem(icon: Icons.people, label: 'Employees', route: '/employees'),
      SidebarItem(icon: Icons.access_time, label: 'Attendance', route: '/attendance'),
      SidebarItem(icon: Icons.calendar_month, label: 'Leave', route: '/leave'),
      SidebarItem(icon: Icons.analytics, label: 'Reports', route: '/reports'),
      SidebarItem(icon: Icons.settings, label: 'Settings', route: '/settings'),
    ];

    // Helper to get initials
    String getInitials(String name) {
      if (name.isEmpty) return 'U';
      final parts = name.trim().split(' ');
      if (parts.length > 1) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    return Container(
      width: 210,
      color: AppColors.darkNavy, // Sidebar is ALWAYS darkNavy regardless of theme mode
      child: Column(
        children: [
          // Top: Logo and Company Info
          Padding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HRNovaLogo(size: 24),
                const SizedBox(height: 4),
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Color(0x13FFFFFF), height: 1),
          const SizedBox(height: 16),
          
          // Navigation Items list
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = currentRoute == item.route;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    onTap: () => onItemTapped(item.route),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    dense: true,
                    selected: isActive,
                    selectedTileColor: const Color(0x134ADE9A),
                    leading: Icon(
                      item.icon,
                      color: isActive ? AppColors.lightGreen : Colors.white60,
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppColors.lightGreen : Colors.white70,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    trailing: (item.badgeCount != null && item.badgeCount! > 0)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item.badgeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          
          // Bottom: Profile Section
          const Divider(color: Color(0x13FFFFFF), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryGreen,
                  child: Text(
                    getInitials(userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.errorRed, size: 18),
                  tooltip: 'Logout',
                  onPressed: () => onItemTapped('sign_out_action'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
