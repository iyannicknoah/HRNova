import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();

  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static String? get currentUserId => auth.currentUser?.uid;

  static Future<Map<String, dynamic>?> getCurrentUserClaims() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final idTokenResult = await user.getIdTokenResult(true);
    return idTokenResult.claims;
  }

  static CollectionReference<Map<String, dynamic>> employeesRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('employees');

  static CollectionReference<Map<String, dynamic>> attendanceRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('attendance');

  static CollectionReference<Map<String, dynamic>> leaveRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('leave_requests');

  static CollectionReference<Map<String, dynamic>> leavesCalendarRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('leaves_calendar');

  static CollectionReference<Map<String, dynamic>> payrollRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('payroll');

  static CollectionReference<Map<String, dynamic>> payslipsRef(
          String companyId, String payrollMonth) =>
      db
          .collection('companies')
          .doc(companyId)
          .collection('payroll')
          .doc(payrollMonth)
          .collection('payslips');

  static CollectionReference<Map<String, dynamic>> performanceRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('performance');

  static CollectionReference<Map<String, dynamic>> reportsRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('reports');

  static CollectionReference<Map<String, dynamic>> jobPostingsRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('job_postings');

  static CollectionReference<Map<String, dynamic>> applicationsRef(
          String companyId, String jobId) =>
      db
          .collection('companies')
          .doc(companyId)
          .collection('job_postings')
          .doc(jobId)
          .collection('applications');

  static DocumentReference<Map<String, dynamic>> settingsRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('settings').doc('config');

  static CollectionReference<Map<String, dynamic>> branchesRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('branches');

  static CollectionReference<Map<String, dynamic>> notificationsRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('notifications');

  static CollectionReference<Map<String, dynamic>> expenseClaimsRef(String companyId) =>
      db.collection('companies').doc(companyId).collection('expense_claims');

  static DocumentReference<Map<String, dynamic>> companiesRegistryRef() =>
      db.collection('super_admin').doc('companies_registry');
}
