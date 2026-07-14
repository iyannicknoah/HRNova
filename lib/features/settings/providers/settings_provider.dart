import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../models/company_settings_model.dart';

// ── Settings write notifier ────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  SettingsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> updateSettings(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _ref.read(currentCompanyIdProvider);
      if (companyId == null) {
        // Loud on purpose — this only happens if the logged-in user's
        // token is missing a companyId claim, which should never be
        // silent since every save in the app depends on it.
        debugPrint('[Settings] updateSettings aborted: no companyId on token. data=$data');
        throw Exception('No company ID found.');
      }
      debugPrint('[Settings] Saving to companies/$companyId/settings/config: $data');
      await FirebaseService.settingsRef(companyId).set(
        {'companyId': companyId, ...data},
        SetOptions(merge: true),
      );
      debugPrint('[Settings] Save confirmed by server for companies/$companyId/settings/config');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint('[Settings] Save FAILED: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<void>>(
  (ref) => SettingsNotifier(ref),
);

// ── Full company settings stream ───────────────────────────────────────────
final companySettingsProvider =
    StreamProvider.autoDispose<CompanySettingsModel?>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(null);

  return FirebaseService.settingsRef(companyId).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return CompanySettingsModel.fromMap(companyId, doc.data()!);
  });
});

// ── Company suspension status ──────────────────────────────────────────────
final companyStatusProvider = StreamProvider.autoDispose<String?>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(null);

  return FirebaseService.db
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((doc) => doc.data()?['status'] as String?);
});

// ── Local override — set to true when wizard completes (design-only bypass) ──
final onboardingCompleteOverrideProvider = StateProvider<bool>((ref) => false);

// ── Onboarding complete check (top-level company admins only: hr_admin for
// single-branch, group_hr_admin for multi-branch) ──────────────────────────
final isOnboardingCompleteProvider = StreamProvider.autoDispose<bool>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  final role = ref.watch(currentUserRoleProvider);

  if (companyId == null) return Stream.value(true);
  if (role != AppConstants.roleHrAdmin && role != AppConstants.roleGroupHrAdmin) {
    return Stream.value(true);
  }

  return FirebaseService.settingsRef(companyId)
      .snapshots()
      .map((doc) => doc.data()?['isOnboardingComplete'] as bool? ?? false);
});
