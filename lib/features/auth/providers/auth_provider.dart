import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Auth state stream ──────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ── User claims ────────────────────────────────────────────────────────────
final userClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  try {
    final result = await user.getIdTokenResult();
    return result.claims;
  } catch (_) {
    // Cached token may be stale — force a refresh.
    final result = await user.getIdTokenResult(true);
    return result.claims;
  }
});

// ── Derived claim providers ────────────────────────────────────────────────
final currentCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(userClaimsProvider).value?['companyId'] as String?;
});

final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(userClaimsProvider).value?['role'] as String?;
});

final currentBranchIdProvider = Provider<String?>((ref) {
  return ref.watch(userClaimsProvider).value?['branchId'] as String?;
});

final currentCompanyTypeProvider = Provider<String?>((ref) {
  return ref.watch(userClaimsProvider).value?['companyType'] as String?;
});

final currentEmployeeIdProvider = Provider<String?>((ref) {
  return ref.watch(userClaimsProvider).value?['employeeId'] as String?;
});

// ── Theme notifier — persists in SharedPreferences ─────────────────────────
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(super.initialMode);

  Future<void> toggle() async {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state.name);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(ThemeMode.light),
);

// ── Auth actions notifier ──────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_friendlyError(e.code), st);
    } catch (e, st) {
      state = AsyncValue.error('Something went wrong. Please try again.', st);
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = const AsyncValue.data(null);
  }

  Future<Map<String, dynamic>?> getUserClaims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult();
    return result.claims;
  }

  Future<String?> getUserRole() async {
    final claims = await getUserClaims();
    return claims?['role'] as String?;
  }

  Future<String?> getCompanyId() async {
    final claims = await getUserClaims();
    return claims?['companyId'] as String?;
  }

  Future<String?> getBranchId() async {
    final claims = await getUserClaims();
    return claims?['branchId'] as String?;
  }

  Future<String?> getCompanyType() async {
    final claims = await getUserClaims();
    return claims?['companyType'] as String?;
  }

  static String _friendlyError(String code) {
    return switch (code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        "That email and password don't match. Double-check and try again.",
      'too-many-requests' =>
        "Too many failed attempts. Please wait a few minutes before trying again.",
      'user-disabled' =>
        "This account has been disabled. Please contact your HR admin.",
      'network-request-failed' =>
        "No internet connection. Please check your network and try again.",
      'invalid-email' =>
        "That doesn't look like a valid email address.",
      'email-already-in-use' =>
        "This email is already registered. Try signing in instead.",
      _ =>
        "Something went wrong. Please try again.",
    };
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);
