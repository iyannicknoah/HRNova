import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/branches/providers/branches_provider.dart';
import 'employee_avatar.dart';
import 'notification_bell.dart';
import '../../core/theme/app_icons.dart';
import '../../shared/widgets/app_icon.dart';
import 'confirm_dialog.dart';

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.route, this.roles});
  final String label;
  final IconRef icon;
  final String route;
  final List<String>? roles;
}

// Routes visible to manager only
const _managerRoutes = {'/dashboard', '/employees', '/attendance', '/leave', '/performance'};

const _navItems = [
  _NavItem(label: 'Dashboard', icon: AppIcons.dashboardRounded, route: '/dashboard'),
  _NavItem(label: 'Employees', icon: AppIcons.peopleRounded, route: '/employees'),
  _NavItem(label: 'Attendance', icon: AppIcons.fingerprintRounded, route: '/attendance'),
  _NavItem(label: 'Leave', icon: AppIcons.beachAccessRounded, route: '/leave'),
  _NavItem(label: 'Payroll', icon: AppIcons.accountBalanceWalletRounded, route: '/payroll'),
  _NavItem(label: 'Performance', icon: AppIcons.trendingUpRounded, route: '/performance'),
  _NavItem(label: 'Reports', icon: AppIcons.barChartRounded, route: '/reports'),
  _NavItem(label: 'Nova AI', icon: AppIcons.autoAwesomeRounded, route: '/nova-ai'),
  _NavItem(label: 'Recruitment', icon: AppIcons.workRounded, route: '/recruitment'),
  _NavItem(
    label: 'Branches',
    icon: AppIcons.businessRounded,
    route: '/branches',
    roles: [AppConstants.roleGroupHrAdmin, AppConstants.roleHrAdmin, AppConstants.roleSuperAdmin],
  ),
  _NavItem(
    label: 'Departments',
    icon: AppIcons.categoryRounded,
    route: '/departments',
    roles: [AppConstants.roleGroupHrAdmin, AppConstants.roleHrAdmin, AppConstants.roleSuperAdmin],
  ),
  _NavItem(label: 'Settings', icon: AppIcons.settingsRounded, route: '/settings'),
];

class HRNovaSidebar extends ConsumerWidget {
  const HRNovaSidebar({
    super.key,
    this.userName = 'HR Admin',
    this.userRole = 'hr_admin',
    this.userPhotoUrl,
    this.companyName = 'HRNovva',
  });

  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final String companyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final companyType = ref.watch(companyTypeProvider).valueOrNull ?? AppConstants.companySingle;
    final isMultiBranch = companyType == AppConstants.companyMultiBranch;

    return Container(
      width: 220,
      color: context.appCard,
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    context.isDark
                        ? 'assets/icon/icon_dark.png'
                        : 'assets/icon/icon_light.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'HRNovva',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: context.appText,
                  ),
                ),
                const Spacer(),
                const NotificationBell(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: context.alternate),
          const SizedBox(height: 16),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _navItems
                  .where((item) {
                    // Manager sees only their 5 routes
                    if (userRole == AppConstants.roleManager && !_managerRoutes.contains(item.route)) return false;
                    if (item.roles != null && !item.roles!.contains(userRole)) return false;
                    if (item.route == '/branches' && !isMultiBranch) return false;
                    // Departments: group_hr_admin on multi-branch, hr_admin on single
                    if (item.route == '/departments') {
                      if (isMultiBranch && userRole != AppConstants.roleGroupHrAdmin && userRole != AppConstants.roleSuperAdmin) return false;
                      if (!isMultiBranch && userRole != AppConstants.roleHrAdmin && userRole != AppConstants.roleSuperAdmin) return false;
                    }
                    return true;
                  })
                  .map((item) => _SidebarItem(
                        item: item,
                        isActive: currentRoute == item.route ||
                            (currentRoute.startsWith(item.route) &&
                                item.route != '/dashboard'),
                      ))
                  .toList(),
            ),
          ),
          // Theme toggle
          _ThemeToggleRow(),
          const SizedBox(height: 6),
          // User info at bottom
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.alternate, width: 1),
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
                          border: Border.all(color: context.appCard, width: 1.5),
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
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _roleLabel(userRole),
                        style: TextStyle(
                          color: context.appSubtext,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Log out?',
                      message: 'Are you sure you want to log out of your account?',
                      confirmLabel: 'Log Out',
                      danger: true,
                    );
                    if (confirmed) {
                      ref.read(authNotifierProvider.notifier).signOut();
                    }
                  },
                  child: Tooltip(
                    message: 'Sign Out',
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: context.appBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppIcon(AppIcons.logoutRounded, size: 16, color: context.appSubtext),
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

class _ThemeToggleRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: context.appTint,
          onTap: () => ref.read(themeNotifierProvider.notifier).toggle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              AppIcon(
                isDark ? AppIcons.lightModeRounded : AppIcons.darkModeRounded,
                size: 18,
                color: context.appSubtext,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDark ? 'Light Mode' : 'Dark Mode',
                  style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 15,
                      fontWeight: FontWeight.w400),
                ),
              ),
              Container(
                width: 36, height: 20,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryBlue : context.appTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.alternate, width: 1),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 14, height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.isActive});

  final _NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // Nudged closer to full-strength text color so inactive items read
    // as a soft near-black rather than the plain faded subtext tone.
    final inactiveColor = Color.alphaBlend(context.appText.withAlpha(90), context.appSubtext);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.route),
          hoverColor: context.appTint,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryBlue.withAlpha(20) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                AppIcon(
                  item.icon,
                  size: 18,
                  color: isActive ? AppColors.primaryBlue : inactiveColor,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive ? AppColors.primaryBlue : inactiveColor,
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
