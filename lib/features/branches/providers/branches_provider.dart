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

  Future<String> addBranch({
    required String name,
    String location = '',
    String branchCode = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _ref.read(currentCompanyIdProvider);
      if (companyId == null) throw Exception('No company ID found.');

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

      state = const AsyncValue.data(null);
      return branchRef.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Assigns an existing branch_hr_admin employee to a branch.
  /// Validates they aren't already assigned elsewhere.
  Future<void> assignExistingHrToBranch(String branchId, {
    required String employeeId,
    required String employeeEmail,
    required String? existingBranchId,
  }) async {
    final companyId = _ref.read(currentCompanyIdProvider);
    if (companyId == null) throw Exception('Not authenticated.');
    if (existingBranchId != null && existingBranchId.isNotEmpty) {
      throw Exception('This HR admin is already assigned to another branch.');
    }
    // Update Firebase claims to add branchId
    await ApiService().post('/api/auth/update-branch-claim', data: {
      'email': employeeEmail,
      'branchId': branchId,
    });
    // Update employee doc
    await FirebaseService.employeesRef(companyId).doc(employeeId).update({
      'branchId': branchId,
    });
    // Update branch doc
    await FirebaseService.branchesRef(companyId).doc(branchId).update({
      'branchHrAdminEmail': employeeEmail,
    });
  }

  /// Creates a new HR admin employee and assigns them to the branch.
  /// Returns the new employee doc ID. Uses the same doc shape/defaults as
  /// [EmployeesNotifier.addEmployee] (qrCode formula, leaveBalances, etc.)
  /// so this admin is a real employee record like anyone else, and marks
  /// `profileComplete: false` so the UI can prompt for the remaining
  /// fields (bank info, RSSB number, etc.) via the same employee form.
  Future<String> addNewHrToBranch(String branchId, {
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final companyId = _ref.read(currentCompanyIdProvider);
    if (companyId == null) throw Exception('Not authenticated.');

    final empRef = FirebaseService.employeesRef(companyId).doc();
    final empId = empRef.id;
    final qrCode = '${companyId}_$empId';

    await empRef.set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': '',
      'role': 'branch_hr_admin',
      'branchId': branchId,
      'companyId': companyId,
      'qrCode': qrCode,
      'department': 'Administration',
      'jobTitle': 'HR Admin',
      'nationalId': '',
      'emergencyContact': '',
      'contractType': 'permanent',
      'startDate': DateTime.now().toIso8601String(),
      'rssbNumber': '',
      'salaryType': 'fixed_monthly',
      'salaryAmount': 0,
      'dailyRate': 0,
      'hourlyRate': 0,
      'transportAllowance': 0,
      'housingAllowance': 0,
      'bankAccount': '',
      'bankCode': '',
      'status': 'active',
      'profileComplete': false,
      'loans': [],
      'leaveBalances': {'annual': 18, 'sick': 10, 'maternity': 84, 'paternity': 4},
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      final resp = await ApiService().post('/api/auth/create-user', data: {
        'email': email,
        'password': password,
        'displayName': '$firstName $lastName',
        'companyId': companyId,
        'role': 'branch_hr_admin',
        'branchId': branchId,
        'employeeId': empId,
      });
      final uid = resp.data?['uid'] as String?;
      if (uid != null) {
        // Persist the exact password that was actually set on the account,
        // so it can be shown correctly later — never re-derive it.
        await empRef.update({'uid': uid, 'initialPassword': password});
        await FirebaseService.branchesRef(companyId).doc(branchId).update({
          'branchHrAdminEmail': email,
          'branchHrAdminUid': uid,
        });
      }
    } catch (e) {
      // Auth creation failed — employee doc exists but no auth account
      await FirebaseService.branchesRef(companyId).doc(branchId).update({
        'branchHrAdminEmail': email,
      });
      rethrow;
    }

    return empId;
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
