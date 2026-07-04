import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/branch_model.dart';

// ── Company type (single vs multi_branch) ────────────────────────────────────
final companyTypeProvider = StreamProvider.autoDispose<String>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value('single');
  return FirebaseService.db
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((d) => d.data()?['companyType'] as String? ?? 'single');
});

// ── Real-time branches stream ─────────────────────────────────────────────────
final branchesStreamProvider = StreamProvider.autoDispose<List<BranchModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);

  return FirebaseService.branchesRef(companyId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map((d) => BranchModel.fromDoc(d)).toList());
});

// ── Branches write notifier ──────────────────────────────────────────────────
class BranchesNotifier extends StateNotifier<AsyncValue<void>> {
  BranchesNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> addBranch({
    required String name,
    String location = '',
    String branchCode = '',
    String? adminEmail,
    String? adminPassword,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _ref.read(currentCompanyIdProvider);
      if (companyId == null) throw Exception('No company ID found.');

      // 1. Always write branch to Firestore directly
      final branchRef = FirebaseService.branchesRef(companyId).doc();
      await branchRef.set({
        'name': name,
        'location': location,
        'branchCode': branchCode,
        'companyId': companyId,
        'isActive': true,
        'employeeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Create branch HR admin account if credentials provided (non-fatal)
      if (adminEmail != null && adminEmail.isNotEmpty &&
          adminPassword != null && adminPassword.isNotEmpty) {
        try {
          await ApiService().post('/api/auth/create-user', data: {
            'email': adminEmail,
            'password': adminPassword,
            'displayName': '$name Admin',
            'companyId': companyId,
            'role': 'branch_hr_admin',
            'branchId': branchRef.id,
          });
        } catch (_) {
          // Auth creation is best-effort — branch is already saved in Firestore
        }
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setActive(String branchId, {required bool isActive}) async {
    final companyId = _ref.read(currentCompanyIdProvider);
    if (companyId == null) return;
    await FirebaseService.branchesRef(companyId)
        .doc(branchId)
        .update({'isActive': isActive});
  }
}

final branchesNotifierProvider =
    StateNotifierProvider<BranchesNotifier, AsyncValue<void>>(
  (ref) => BranchesNotifier(ref),
);
