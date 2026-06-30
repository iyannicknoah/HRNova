import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/company_settings_model.dart';

// ── Full company settings stream ───────────────────────────────────────────
final companySettingsProvider =
    StreamProvider.autoDispose<CompanySettingsModel?>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return const Stream.empty();

  return FirebaseService.settingsRef(companyId).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return CompanySettingsModel.fromMap(companyId, doc.data()!);
  });
});

// ── Company suspension status ──────────────────────────────────────────────
final companyStatusProvider = StreamProvider.autoDispose<String?>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((doc) => doc.data()?['status'] as String?);
});

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
