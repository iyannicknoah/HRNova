import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'employee_avatar.dart';
import 'notification_bell.dart';

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.route, this.roles});
  final String label;
  final IconData icon;
  final String route;
  final List<String>? roles;
}

const _navItems = [
  _NavItem(label: 'Dashboard', icon: Icons.dashboard_rounded, route: '/dashboard'),
  _NavItem(label: 'Employees', icon: Icons.people_rounded, route: '/employees'),
  _NavItem(label: 'Attendance', icon: Icons.fingerprint_rounded, route: '/attendance'),
  _NavItem(label: 'Leave', icon: Icons.beach_access_rounded, route: '/leave'),
  _NavItem(label: 'Payroll', icon: Icons.account_balance_wallet_rounded, route: '/payroll'),
  _NavItem(label: 'Performance', icon: Icons.trending_up_rounded, route: '/performance'),
  _NavItem(label: 'Reports', icon: Icons.bar_chart_rounded, route: '/reports'),
  _NavItem(label: 'Nova AI', icon: Icons.auto_awesome_rounded, route: '/nova-ai'),
  _NavItem(label: 'Recruitment', icon: Icons.work_rounded, route: '/recruitment'),
  _NavItem(
    label: 'Branches',
    icon: Icons.business_rounded,
    route: '/branches',
    roles: [AppConstants.roleGroupHrAdmin, AppConstants.roleHrAdmin, AppConstants.roleSuperAdmin],
  ),
  _NavItem(label: 'Settings', icon: Icons.settings_rounded, route: '/settings'),
];

class HRNovaSidebar extends ConsumerWidget {
  const HRNovaSidebar({
    super.key,
    this.userName = 'HR Admin',
    this.userRole = 'hr_admin',
    this.userPhotoUrl,
    this.companyName = 'HRNova',
  });

  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final String companyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.path;

    return Container(
      width: 220,
      color: AppColors.darkNavy,
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        children: [
                          TextSpan(text: 'HR', style: TextStyle(color: AppColors.white)),
                          TextSpan(text: 'Nova', style: TextStyle(color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const NotificationBell(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  companyName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Blue separator line
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withAlpha(0),
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withAlpha(0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _navItems
                  .where((item) =>
                      item.roles == null || item.roles!.contains(userRole))
                  .map((item) => _SidebarItem(
                        item: item,
                        isActive: currentRoute == item.route ||
                            (currentRoute.startsWith(item.route) &&
                                item.route != '/dashboard'),
                      ))
                  .toList(),
            ),
          ),
          // User info at bottom
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white.withAlpha(15), width: 0.5),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    EmployeeAvatar(
                      name: userName,
                      photoUrl: userPhotoUrl,
                      size: 36,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.darkNavy, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _roleLabel(userRole),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
                  child: Tooltip(
                    message: 'Sign Out',
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      AppConstants.roleHrAdmin => 'HR Admin',
      AppConstants.roleGroupHrAdmin => 'Group HR Admin',
      AppConstants.roleBranchHrAdmin => 'Branch HR Admin',
      AppConstants.roleManager => 'Manager',
      AppConstants.roleDirector => 'Director',
      AppConstants.roleFinanceManager => 'Finance Manager',
      AppConstants.roleSuperAdmin => 'Super Admin',
      _ => role.replaceAll('_', ' '),
    };
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.isActive});

  final _NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.route),
          hoverColor: AppColors.white.withAlpha(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryBlue.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: AppColors.primaryBlue.withAlpha(60), width: 0.5)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isActive ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive ? AppColors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
