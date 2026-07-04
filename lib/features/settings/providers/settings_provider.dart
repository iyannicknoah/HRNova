import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/company_settings_model.dart';

// ── Settings write notifier ────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  SettingsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> updateSettings(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _ref.read(currentCompanyIdProvider);
      if (companyId == null) throw Exception('No company ID found.');
      await FirebaseService.settingsRef(companyId).set(
        {'companyId': companyId, ...data},
        SetOptions(merge: true),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
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

// ── Onboarding complete check (hr_admin only) ─────────────────────────────
final isOnboardingCompleteProvider = StreamProvider.autoDispose<bool>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  final role = ref.watch(currentUserRoleProvider);

  if (companyId == null) return Stream.value(true);
  if (role != AppConstants.roleHrAdmin) return Stream.value(true);

  return FirebaseService.settingsRef(companyId)
      .snapshots()
      .map((doc) => doc.data()?['isOnboardingComplete'] as bool? ?? false);
});
