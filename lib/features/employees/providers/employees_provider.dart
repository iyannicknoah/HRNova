import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../models/employee_model.dart';

final employeesProvider = StreamProvider.autoDispose<List<EmployeeModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return const Stream.empty();

  return FirebaseService.employeesRef(companyId)
      .where('status', whereNotIn: ['deleted'])
      .orderBy('firstName')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => EmployeeModel.fromMap(doc.id, doc.data()))
          .toList());
});

final employeeByIdProvider =
    StreamProvider.autoDispose.family<EmployeeModel?, String>((ref, employeeId) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return const Stream.empty();

  return FirebaseService.employeesRef(companyId)
      .doc(employeeId)
      .snapshots()
      .map((doc) => doc.exists ? EmployeeModel.fromMap(doc.id, doc.data()!) : null);
});

final activeEmployeesProvider = Provider.autoDispose<AsyncValue<List<EmployeeModel>>>((ref) {
  return ref.watch(employeesProvider).whenData(
        (employees) => employees.where((e) => e.status == 'active').toList(),
      );
});
