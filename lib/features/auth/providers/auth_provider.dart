import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  // Watch authStateProvider to automatically update current user on auth changes
  ref.watch(authStateProvider);
  return FirebaseAuth.instance.currentUser;
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is void/idle
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncValue.error('Invalid email or password. Please try again.', StackTrace.current);
      throw 'Invalid email or password. Please try again.';
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await FirebaseAuth.instance.signOut();
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<String?> getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims?['role'] as String?;
  }

  Future<String?> getCompanyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims?['companyId'] as String?;
  }

  Future<Map<String, dynamic>?> getUserClaims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims;
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(() {
  return AuthNotifier();
});

final userClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  // Fetch token result (forceRefresh: true on auth changes is already handled elsewhere, but normal get is sufficient here)
  final tokenResult = await user.getIdTokenResult();
  return tokenResult.claims;
});

final companyIdProvider = Provider<String?>((ref) {
  final claimsAsync = ref.watch(userClaimsProvider);
  return claimsAsync.maybeWhen(
    data: (claims) => claims?['companyId'] as String?,
    orElse: () => null,
  );
});

final userRoleProvider = Provider<String?>((ref) {
  final claimsAsync = ref.watch(userClaimsProvider);
  return claimsAsync.maybeWhen(
    data: (claims) => claims?['role'] as String?,
    orElse: () => null,
  );
});

final companyNameProvider = FutureProvider<String>((ref) async {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return 'HRNova';

  try {
    final doc = await FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    ).collection('companies').doc(companyId).get();
    return doc.data()?['name'] as String? ?? 'HRNova';
  } catch (_) {
    return 'HRNova';
  }
});
