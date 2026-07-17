import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../models/employee_model.dart';

// ── Streams ───────────────────────────────────────────────────────────────────

final employeesProvider = StreamProvider.autoDispose<List<EmployeeModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);

  final role = ref.watch(currentUserRoleProvider);
  final branchId = ref.watch(currentBranchIdProvider);

  // Branch HR admin or manager: filter by branchId.
  // Manager with no branchId (single-company) sees everyone.
  final scopeByBranch = (role == AppConstants.roleBranchHrAdmin ||
          role == AppConstants.roleManager) &&
      branchId != null;
  if (scopeByBranch) {
    return FirebaseService.employeesRef(companyId)
        .where('branchId', isEqualTo: branchId)
        .orderBy('firstName')
        .snapshots()
        .map((s) => s.docs
            .map((d) => EmployeeModel.fromDoc(d))
            .where((e) => e.status != 'deleted')
            .toList());
  }

  return FirebaseService.employeesRef(companyId)
      .where('status', whereNotIn: ['deleted'])
      .orderBy('firstName')
      .snapshots()
      .map((s) => s.docs.map((d) => EmployeeModel.fromDoc(d)).toList());
});

final employeeByIdProvider =
    StreamProvider.autoDispose.family<EmployeeModel?, String>((ref, employeeId) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(null);

  return FirebaseService.employeesRef(companyId)
      .doc(employeeId)
      .snapshots()
      .map((doc) => doc.exists ? EmployeeModel.fromDoc(doc) : null);
});

final activeEmployeesProvider = Provider.autoDispose<AsyncValue<List<EmployeeModel>>>((ref) {
  return ref.watch(employeesProvider).whenData(
        (list) => list.where((e) => e.status == 'active').toList(),
      );
});

// Stream the current logged-in employee's profile via their employeeId claim
final currentEmployeeProvider =
    StreamProvider.autoDispose<EmployeeModel?>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  final employeeId = ref.watch(currentEmployeeIdProvider);
  if (companyId == null || employeeId == null) return Stream.value(null);
  return FirebaseService.employeesRef(companyId)
      .doc(employeeId)
      .snapshots()
      .map((doc) => doc.exists ? EmployeeModel.fromDoc(doc) : null);
});

final employeeByQRProvider =
    FutureProvider.autoDispose.family<EmployeeModel?, String>((ref, qrCode) async {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return null;

  final snap = await FirebaseService.employeesRef(companyId)
      .where('qrCode', isEqualTo: qrCode)
      .limit(1)
      .get();

  if (snap.docs.isEmpty) return null;
  return EmployeeModel.fromDoc(snap.docs.first);
});

// ── Employee limit: (current active company-wide, max allowed) ───────────────

typedef _LimitRecord = ({int current, int max});

final companyEmployeeLimitProvider =
    StreamProvider.autoDispose<_LimitRecord>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value((current: 0, max: 0));

  final companyStream = FirebaseService.db
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((d) => (d.data()?['employeeCount'] as num?)?.toInt() ?? 0);

  final countStream = FirebaseService.employeesRef(companyId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.length);

  return companyStream.asyncExpand((maxEmployees) => countStream
      .map((current) => (current: current, max: maxEmployees)));
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class EmployeesNotifier extends StateNotifier<AsyncValue<void>> {
  EmployeesNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  String? get _companyId => _ref.read(currentCompanyIdProvider);

  /// Returns (docId, tempPassword, authError). tempPassword is null if no
  /// email was provided, or if account creation failed — in which case
  /// authError carries the actual reason (e.g. "That email is already
  /// registered") so the caller can show it instead of failing silently.
  Future<(String, String?, String?)> addEmployee({
    required Map<String, dynamic> data,
    Uint8List? photoBytes,
    String? companyIdOverride,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = companyIdOverride ?? _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      // Check company-wide employee limit before adding
      final companyDoc = await FirebaseService.db
          .collection('companies')
          .doc(companyId)
          .get();
      final maxAllowed = (companyDoc.data()?['employeeCount'] as num?)?.toInt() ?? 0;
      if (maxAllowed > 0) {
        final activeSnap = await FirebaseService.employeesRef(companyId)
            .where('status', isEqualTo: 'active')
            .count()
            .get();
        final currentCount = activeSnap.count ?? 0;
        if (currentCount >= maxAllowed) {
          throw Exception(
              'Employee limit reached ($currentCount / $maxAllowed). '
              'Contact your administrator to increase the limit.');
        }
      }

      // Catch duplicate emails before creating a second employee record for
      // the same address — otherwise the new doc gets created but the auth
      // account creation below fails with "email already exists" (silently,
      // if not for the fix further down), leaving an employee with no
      // working login.
      final requestedEmail = data['email'] as String?;
      if (requestedEmail != null && requestedEmail.isNotEmpty) {
        // Single-field equality query — deliberately not combined with a
        // second `where` here, since that could require a composite index
        // that may not exist. Filter out deleted records client-side instead.
        final dupSnap = await FirebaseService.employeesRef(companyId)
            .where('email', isEqualTo: requestedEmail)
            .get();
        if (dupSnap.docs.any((d) => d.data()['status'] != 'deleted')) {
          throw Exception('An employee with this email already exists.');
        }
      }

      // National ID must be unique within the company (the same ID can
      // still belong to different employees at two different companies).
      final requestedNationalId = data['nationalId'] as String?;
      if (requestedNationalId != null && requestedNationalId.isNotEmpty) {
        final dupIdSnap = await FirebaseService.employeesRef(companyId)
            .where('nationalId', isEqualTo: requestedNationalId)
            .get();
        if (dupIdSnap.docs.any((d) => d.data()['status'] != 'deleted')) {
          throw Exception('An employee with this National ID already exists.');
        }
      }

      final docRef = FirebaseService.employeesRef(companyId).doc();
      final docId = docRef.id;
      final qrCode = '${companyId}_$docId';

      String? photoUrl;
      if (photoBytes != null) {
        photoUrl = await _uploadPhoto(companyId, docId, photoBytes);
      }

      final settingsDoc = await FirebaseService.settingsRef(companyId).get();
      final settings = settingsDoc.data() ?? {};
      final leaveBalances = {
        'annual': (settings['annualLeaveDays'] as num?)?.toInt() ?? 18,
        'sick': (settings['sickLeaveDays'] as num?)?.toInt() ?? 10,
        'maternity': 84,
        'paternity': 4,
      };

      await docRef.set({
        ...data,
        'companyId': companyId,
        'qrCode': qrCode,
        if (photoUrl != null) 'profilePhotoUrl': photoUrl,
        'leaveBalances': leaveBalances,
        'loans': [],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a Firebase Auth account for every role that has an email
      final email = data['email'] as String?;
      final customPassword = data['password'] as String?;
      String? tempPassword;
      String? authError;
      if (email != null && email.isNotEmpty) {
        tempPassword = customPassword != null && customPassword.isNotEmpty
            ? customPassword
            : '${companyId.substring(0, 4)}@${docId.substring(0, 6)}';
        try {
          await ApiService().post('/api/auth/create-user', data: {
            'email': email,
            'password': tempPassword,
            'displayName': '${data['firstName']} ${data['lastName']}',
            'companyId': companyId,
            'role': data['role'] ?? 'employee',
            'employeeId': docId,
            if (data['branchId'] != null) 'branchId': data['branchId'],
          });
          // Persist the exact password that was actually set on the account,
          // so it can be shown correctly later — never re-derive it.
          await docRef.update({'initialPassword': tempPassword});
        } catch (e) {
          // Auth creation is non-fatal to the employee record — it's
          // already saved — but the caller needs the real reason so the
          // admin can actually see and fix why no account was created,
          // instead of it failing invisibly.
          tempPassword = null;
          authError = e.toString().replaceFirst('Exception: ', '');
        }
      }

      state = const AsyncValue.data(null);
      return (docId, tempPassword, authError);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateEmployee(String employeeId, Map<String, dynamic> data, {Uint8List? photoBytes, String? companyIdOverride}) async {
    state = const AsyncValue.loading();
    try {
      final companyId = companyIdOverride ?? _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final requestedNationalId = data['nationalId'] as String?;
      if (requestedNationalId != null && requestedNationalId.isNotEmpty) {
        final dupIdSnap = await FirebaseService.employeesRef(companyId)
            .where('nationalId', isEqualTo: requestedNationalId)
            .get();
        if (dupIdSnap.docs.any((d) => d.id != employeeId && d.data()['status'] != 'deleted')) {
          throw Exception('An employee with this National ID already exists.');
        }
      }

      if (photoBytes != null) {
        final url = await _uploadPhoto(companyId, employeeId, photoBytes);
        data['profilePhotoUrl'] = url;
      }

      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update(data);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deactivate(String employeeId) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'status': 'inactive'});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteEmployee(String employeeId, {String? email}) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      // Delete Firebase Auth account (non-fatal — Firestore delete proceeds regardless)
      if (email != null && email.isNotEmpty) {
        try {
          await ApiService().delete('/api/auth/delete-user', data: {'email': email});
        } catch (_) {}
      }
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'status': 'deleted', 'deletedAt': FieldValue.serverTimestamp()});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> transferBranch(String employeeId, String newBranchId, {String? email}) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'branchId': newBranchId});
      // Update Auth claim so the employee's next login gets the correct branchId
      if (email != null && email.isNotEmpty) {
        try {
          await ApiService().post('/api/auth/update-branch-claim',
              data: {'email': email, 'branchId': newBranchId});
        } catch (_) {}
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> addLoan(String employeeId, Map<String, dynamic> loan) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      // Normalize so the payroll engine can pick the loan up: it deducts only
      // when status == 'active' and remainingAmount > 0.
      final total = (loan['totalAmount'] as num?)?.toDouble() ?? 0;
      final paid = (loan['amountPaid'] as num?)?.toDouble() ?? 0;
      final normalized = {
        ...loan,
        'amountPaid': paid,
        'remainingAmount':
            (loan['remainingAmount'] as num?)?.toDouble() ?? (total - paid).clamp(0.0, total),
        'status': loan['status'] as String? ?? 'active',
      };
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'loans': FieldValue.arrayUnion([normalized])});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> regenerateQR(String employeeId) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final newQR = '${companyId}_${employeeId}_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'qrCode': newQR});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> _uploadPhoto(String companyId, String employeeId, Uint8List bytes) async {
    final compressed = _compress(bytes);
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        compressed,
        filename: '$employeeId.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      'companyId': companyId,
      'employeeId': employeeId,
    });
    final res = await ApiService().postMultipart('/api/storage/upload-photo', formData);
    return res.data['url'] as String;
  }

  static Uint8List _compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    // Resize if too large
    final resized = decoded.width > 800
        ? img.copyResize(decoded, width: 800)
        : decoded;
    // Encode as JPEG at quality 80, reduce until < 100KB
    for (var quality = 80; quality > 20; quality -= 10) {
      final encoded = img.encodeJpg(resized, quality: quality);
      if (encoded.length <= 100 * 1024) return Uint8List.fromList(encoded);
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: 20));
  }
}

final employeesNotifierProvider =
    StateNotifierProvider<EmployeesNotifier, AsyncValue<void>>(
  (ref) => EmployeesNotifier(ref),
);

// ── Photo picker helper ───────────────────────────────────────────────────────

Future<Uint8List?> pickPhoto() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  return await picked.readAsBytes();
}
