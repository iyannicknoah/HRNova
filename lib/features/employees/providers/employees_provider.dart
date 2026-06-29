import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/company_settings_model.dart';
import '../models/employee_model.dart';
import '../../../core/services/api_service.dart';

final employeesProvider = StreamProvider<List<Employee>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection('companies')
      .doc(companyId)
      .collection('employees')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();
      });
});

final employeeByQRProvider = FutureProvider.family<Employee?, String>((ref, qrCode) async {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return null;

  final snapshot = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection('companies')
      .doc(companyId)
      .collection('employees')
      .where('qrCode', isEqualTo: qrCode)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return null;
  return Employee.fromFirestore(snapshot.docs.first);
});

class EmployeesNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  EmployeesNotifier(this._ref) : super(const AsyncData(null));

  Future<String?> saveEmployee({
    required String? id, // null for new employee
    required String firstName,
    required String lastName,
    required String nationalId,
    required String phone,
    required String email,
    required String department,
    required String jobTitle,
    required String contractType,
    required DateTime startDate,
    required DateTime? endDate,
    required String salaryType,
    required double salaryAmount,
    required double dailyRate,
    required String role,
    required String? managerTempPassword, // only needed if new manager
  }) async {
    final companyId = _ref.read(companyIdProvider);
    if (companyId == null) {
      state = AsyncValue.error('No company session found.', StackTrace.current);
      throw 'No company session found.';
    }

    state = const AsyncLoading();
    try {
      final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
      final isNew = id == null;
      
      final docId = id ?? db.collection('companies').doc(companyId).collection('employees').doc().id;
      final docRef = db.collection('companies').doc(companyId).collection('employees').doc(docId);

      Map<String, int> leaveBalances;
      String existingStatus = 'active';
      DateTime existingCreatedAt = DateTime.now();

      if (isNew) {
        // Fetch current settings for initializing leave balances
        final settingsAsync = _ref.read(settingsProvider);
        final settings = settingsAsync.value ?? const CompanySettings();

        leaveBalances = {
          'annual': settings.annualLeaveDays,
          'sick': settings.sickLeaveDays,
          'maternity': 84,
          'paternity': 4,
        };
      } else {
        // Single read to preserve existing leaveBalances, status, and createdAt
        final existingDoc = await docRef.get();
        final existingData = existingDoc.data() ?? {};
        leaveBalances = Map<String, int>.from(existingData['leaveBalances'] ?? {
          'annual': 18,
          'sick': 10,
          'maternity': 84,
          'paternity': 4,
        });
        existingStatus = existingData['status'] as String? ?? 'active';
        existingCreatedAt = existingData['createdAt'] != null
            ? (existingData['createdAt'] as Timestamp).toDate()
            : DateTime.now();
      }

      final qrCode = '${companyId}_$docId';

      final employee = Employee(
        id: docId,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        nationalId: nationalId.trim(),
        phone: phone.trim(),
        email: email.trim().toLowerCase(),
        department: department,
        jobTitle: jobTitle.trim(),
        contractType: contractType,
        startDate: startDate,
        endDate: endDate,
        salaryType: salaryType,
        salaryAmount: salaryAmount,
        dailyRate: dailyRate,
        role: role,
        qrCode: qrCode,
        status: isNew ? 'active' : existingStatus,
        leaveBalances: leaveBalances,
        createdAt: isNew ? DateTime.now() : existingCreatedAt,
      );

      // If new manager is requested, create their account via backend API first
      if (isNew && role == 'manager') {
        if (managerTempPassword == null || managerTempPassword.trim().isEmpty) {
          throw 'Temporary password is required to register a manager login account.';
        }

        final apiService = _ref.read(apiServiceProvider);
        final response = await apiService.post(
          '/api/auth/create-user',
          data: {
            'email': email.trim().toLowerCase(),
            'password': managerTempPassword.trim(),
            'role': 'manager',
            'companyId': companyId,
            'displayName': '${firstName.trim()} ${lastName.trim()}',
          },
        );

        if (response.statusCode != 201) {
          throw 'Backend user creation failed: ${response.data['error'] ?? 'Unknown Error'}';
        }
      }

      // Save to Firestore
      await docRef.set(employee.toFirestore(), SetOptions(merge: true));

      state = const AsyncData(null);
      return docId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateLeaveBalance(
    String employeeId,
    String leaveType,
    int newBalance,
  ) async {
    final companyId = _ref.read(companyIdProvider);
    if (companyId == null) return;

    state = const AsyncLoading();
    try {
      final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
      final empRef = db.collection('companies').doc(companyId).collection('employees').doc(employeeId);

      await empRef.update({
        'leaveBalances.$leaveType': newBalance,
      });

      // Write audit log entry
      await empRef.collection('auditLogs').add({
        'action': 'leave_balance_adjustment',
        'leaveType': leaveType,
        'newBalance': newBalance,
        'timestamp': FieldValue.serverTimestamp(),
      });

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> setStatus(String employeeId, String status) async {
    final companyId = _ref.read(companyIdProvider);
    if (companyId == null) return;

    state = const AsyncLoading();
    try {
      final docRef = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .doc(employeeId);

      await docRef.update({
        'status': status,
      });

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final employeesNotifierProvider = StateNotifierProvider<EmployeesNotifier, AsyncValue<void>>((ref) {
  return EmployeesNotifier(ref);
});
