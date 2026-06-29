import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/suspension_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/employees/screens/employees_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/tablet_checkin_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/super_admin/screens/super_admin_screen.dart';
import '../../features/mobile/screens/mobile_home_screen.dart';

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Listen to changes in the auth state and trigger notifier
    _ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final loggingIn = state.matchedLocation == '/login';

        if (user == null) {
          return loggingIn ? null : '/login';
        }

        // Fetch custom token claims to determine roles
        final tokenResult = await user.getIdTokenResult().timeout(const Duration(seconds: 4));
        final role = tokenResult.claims?['role'] as String?;
        final companyId = tokenResult.claims?['companyId'] as String?;

        if (role == null) {
          await FirebaseAuth.instance.signOut();
          return '/login';
        }

        // Suspension verification check for manager and admin accounts
        if (role == 'hr_admin' || role == 'manager') {
          if (companyId != null) {
            try {
              final companyDoc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
                  .collection('companies')
                  .doc(companyId)
                  .get();
              final status = companyDoc.data()?['status'] as String?;
              if (status == 'suspended') {
                return state.matchedLocation == '/suspended' ? null : '/suspended';
              }
            } catch (e) {
              // Silence network error inside redirect to avoid infinite redirect loops
            }
          }
        }

        // If user is at root or not suspended but tries to visit the suspension screen, route them home
        if (state.matchedLocation == '/' || state.matchedLocation == '/suspended') {
          if (role == 'super_admin') return '/super-admin';
          if (role == 'employee') return '/mobile-home';
          return '/dashboard';
        }

        if (loggingIn) {
          switch (role) {
            case 'super_admin':
              return '/super-admin';
            case 'hr_admin':
            case 'manager':
              return '/dashboard';
            case 'employee':
              return '/mobile-home';
            default:
              await FirebaseAuth.instance.signOut();
              return '/login';
          }
        }

        // Security guards: Redirect if accessing unauthorized screens
        final location = state.matchedLocation;
        if (location == '/super-admin' && role != 'super_admin') {
          return '/login';
        }
        if ((location == '/dashboard' ||
                location == '/employees' ||
                location == '/attendance' ||
                location == '/leave' ||
                location == '/reports' ||
                location == '/settings') &&
            (role != 'hr_admin' && role != 'manager')) {
          return '/login';
        }
        if (location == '/mobile-home' && role != 'employee') {
          return '/login';
        }

        return null;
      } catch (e) {
        // Sign out to clean potentially corrupted auth state and redirect to login
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        return '/login';
      }
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspensionScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/tablet-checkin',
        builder: (context, state) => const TabletCheckinScreen(),
      ),
      GoRoute(
        path: '/leave',
        builder: (context, state) => const LeaveScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const SuperAdminScreen(),
      ),
      GoRoute(
        path: '/mobile-home',
        builder: (context, state) => const MobileHomeScreen(),
      ),
    ],
  );
});
