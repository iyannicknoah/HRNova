import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/branch_model.dart';

// ── Real-time branches stream ─────────────────────────────────────────────────
final branchesStreamProvider = StreamProvider.autoDispose<List<BranchModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return const Stream.empty();

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

      if (adminEmail != null && adminEmail.isNotEmpty &&
          adminPassword != null && adminPassword.isNotEmpty) {
        // Backend creates the branch + Firebase Auth account
        await ApiService().post('/api/branches', data: {
          'name': name,
          'location': location,
          'branchCode': branchCode,
          'adminEmail': adminEmail,
          'adminPassword': adminPassword,
        });
      } else {
        // Direct Firestore write — no HR admin account needed
        await FirebaseService.branchesRef(companyId).add({
          'name': name,
          'location': location,
          'branchCode': branchCode,
          'companyId': companyId,
          'isActive': true,
          'employeeCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
