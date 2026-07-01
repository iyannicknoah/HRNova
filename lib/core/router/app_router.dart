import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/settings/providers/settings_provider.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/suspension_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/employees/screens/employees_screen.dart';
import '../../features/employees/screens/employee_add_screen.dart';
import '../../features/employees/screens/employee_profile_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/guard_mode_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/payroll/screens/payroll_screen.dart';
import '../../features/performance/screens/performance_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/reports/screens/nova_ai_screen.dart';
import '../../features/recruitment/screens/recruitment_screen.dart';
import '../../features/recruitment/screens/job_posting_screen.dart';
import '../../features/recruitment/screens/application_detail_screen.dart';
import '../../features/public/screens/job_board_screen.dart';
import '../../features/public/screens/apply_screen.dart';
import '../../features/public/screens/application_success_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/onboarding_screen.dart';
import '../../features/super_admin/screens/super_admin_screen.dart';
import '../../features/mobile/screens/mobile_home_screen.dart';
import '../../features/branches/screens/branches_screen.dart';
import '../../shared/widgets/hrnova_sidebar.dart';

bool _isPublicRoute(String path) {
  return path.startsWith('/apply') ||
      path.startsWith('/jobs') ||
      path == '/apply-success';
}

// ── Router notifier ────────────────────────────────────────────────────────
// Holds the GoRouter as its state. Uses ref.listen (not ref.watch) so build()
// runs exactly once — the GoRouter is created once and never recreated.
// When auth/claims/status change, state.refresh() is called directly on the
// GoRouter, which is guaranteed to re-invoke redirect() on the next frame.
class AppRouterNotifier extends Notifier<GoRouter> {
  @override
  GoRouter build() {
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, _) {
      Future.microtask(() => state.refresh());
    });
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userClaimsProvider, (_, _) {
      Future.microtask(() => state.refresh());
    });
    ref.listen<AsyncValue<String?>>(companyStatusProvider, (_, next) {
      Future.microtask(() => state.refresh());
    });
    ref.listen<AsyncValue<bool>>(isOnboardingCompleteProvider, (_, next) {
      Future.microtask(() => state.refresh());
    });
    ref.listen<bool>(onboardingCompleteOverrideProvider, (_, __) {
      Future.microtask(() => state.refresh());
    });

    return GoRouter(
      initialLocation: '/login',
      redirect: _redirect,
      routes: _buildRoutes(),
      errorBuilder: (context, s) => _RouterErrorScreen(error: s.error),
    );
  }

  String? _redirect(BuildContext context, GoRouterState routerState) {
    final path = routerState.uri.path;

    if (_isPublicRoute(path)) return null;

    final authAsync = ref.read(authStateProvider);
    if (authAsync.hasError) return path == '/login' ? null : '/login';
    if (authAsync.isLoading) return null;

    final user = authAsync.value;
    if (user == null) return path == '/login' ? null : '/login';

    final claimsAsync = ref.read(userClaimsProvider);
    if (claimsAsync.isLoading) return null;
    if (claimsAsync.hasError) return null;

    final claims = claimsAsync.value;
    final role = claims?['role'] as String?;
    final companyId = claims?['companyId'] as String?;

    // Super admin — unrestricted (no company scope)
    if (role == AppConstants.roleSuperAdmin) {
      if (path == '/login' || path == '/suspended' || path == '/') {
        return '/super-admin';
      }
      return null;
    }

    // Unknown role — sign out and return to login
    if (role == null) {
      FirebaseAuth.instance.signOut();
      return path == '/login' ? null : '/login';
    }

    // Suspension check
    if (companyId != null) {
      final statusAsync = ref.read(companyStatusProvider);
      if (!statusAsync.isLoading) {
        final status = statusAsync.value;
        if (status == 'suspended' && path != '/suspended') return '/suspended';
        if (status != 'suspended' && path == '/suspended') return _homeForRole(role);
      }
    }

    // Onboarding check — hr_admin only
    if (role == AppConstants.roleHrAdmin) {
      final localDone = ref.read(onboardingCompleteOverrideProvider);
      if (localDone) {
        if (path == '/onboarding') return '/dashboard';
      } else {
        final onboardingAsync = ref.read(isOnboardingCompleteProvider);
        if (!onboardingAsync.isLoading) {
          final isComplete = onboardingAsync.value ?? false;
          if (!isComplete && path != '/onboarding') return '/onboarding';
          if (isComplete && path == '/onboarding') return '/dashboard';
        }
      }
    }

    // From /login → role-based home
    if (path == '/login') return _homeForRole(role);

    // Guard is restricted to guard-mode only
    if (role == AppConstants.roleGuard && path != '/guard-mode') return '/guard-mode';

    // Employee is restricted to mobile-home only
    if (role == AppConstants.roleEmployee && path != '/mobile-home') return '/mobile-home';

    return null;
  }

  String _homeForRole(String? role) {
    return switch (role) {
      AppConstants.roleSuperAdmin => '/super-admin',
      AppConstants.roleGuard => '/guard-mode',
      AppConstants.roleEmployee => '/mobile-home',
      _ => '/dashboard',
    };
  }
}

final appRouterProvider =
    NotifierProvider<AppRouterNotifier, GoRouter>(AppRouterNotifier.new);

// ── Route definitions ──────────────────────────────────────────────────────
List<RouteBase> _buildRoutes() => [
      // ── Public / unauthenticated ─────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspensionScreen(),
      ),
      GoRoute(
        path: '/apply-success',
        builder: (context, state) => const ApplicationSuccessScreen(),
      ),
      GoRoute(
        path: '/jobs/:companySlug',
        builder: (context, state) => JobBoardScreen(
          companySlug: state.pathParameters['companySlug']!,
        ),
      ),
      GoRoute(
        path: '/apply/:companySlug/:jobSlug',
        builder: (context, state) => ApplyScreen(
          companySlug: state.pathParameters['companySlug']!,
          jobSlug: state.pathParameters['jobSlug']!,
        ),
      ),

      // ── Onboarding (authenticated, no sidebar) ───────────────────────────
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Standalone authenticated routes (no sidebar) ─────────────────────
      GoRoute(
        path: '/guard-mode',
        builder: (context, state) => const GuardModeScreen(),
      ),
      GoRoute(
        path: '/mobile-home',
        builder: (context, state) => const MobileHomeScreen(),
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const SuperAdminScreen(),
      ),

      // ── Dashboard shell (sidebar) ─────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _SidebarShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => EmployeeAddScreen(
                  editId: state.uri.queryParameters['editId'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => EmployeeProfileScreen(
                  employeeId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/leave',
            builder: (context, state) => const LeaveScreen(),
          ),
          GoRoute(
            path: '/payroll',
            builder: (context, state) => const PayrollScreen(),
          ),
          GoRoute(
            path: '/performance',
            builder: (context, state) => const PerformanceScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/nova-ai',
            builder: (context, state) => const NovaAiScreen(),
          ),
          GoRoute(
            path: '/recruitment',
            builder: (context, state) => const RecruitmentScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const JobPostingScreen(),
              ),
              GoRoute(
                path: ':jobId',
                builder: (context, state) => JobPostingScreen(
                  jobId: state.pathParameters['jobId'],
                ),
                routes: [
                  GoRoute(
                    path: 'application/:appId',
                    builder: (context, state) => ApplicationDetailScreen(
                      jobId: state.pathParameters['jobId']!,
                      applicationId: state.pathParameters['appId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/branches',
            builder: (context, state) => const BranchesScreen(),
          ),
        ],
      ),
    ];

// ── Sidebar shell ─────────────────────────────────────────────────────────
class _SidebarShell extends ConsumerWidget {
  const _SidebarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(userClaimsProvider);
    final claims = claimsAsync.value;

    return Scaffold(
      body: Row(
        children: [
          HRNovaSidebar(
            userName: claims?['displayName'] as String? ?? 'HR Admin',
            userRole: claims?['role'] as String? ?? 'hr_admin',
            companyName: claims?['companyName'] as String? ?? 'HRNova',
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Router error screen ────────────────────────────────────────────────────
class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE5534B), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style:
                    const TextStyle(color: Color(0xFF6B7A99), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login',
                  style: TextStyle(color: Color(0xFF4A9EFF))),
            ),
          ],
        ),
      ),
    );
  }
}
