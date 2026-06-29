import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  FirebaseService._();

  static FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static String? get currentUserId => auth.currentUser?.uid;

  static Future<Map<String, dynamic>?> getCurrentUserClaims() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims;
  }

  // Scoped collection references by companyId
  static CollectionReference employeesRef(String companyId) {
    return db.collection('companies').doc(companyId).collection('employees');
  }

  static CollectionReference attendanceRef(String companyId) {
    return db.collection('companies').doc(companyId).collection('attendance');
  }

  static CollectionReference leaveRef(String companyId) {
    return db.collection('companies').doc(companyId).collection('leave_requests');
  }

  static CollectionReference reportsRef(String companyId) {
    return db.collection('companies').doc(companyId).collection('reports');
  }

  static DocumentReference settingsRef(String companyId) {
    return db.collection('companies').doc(companyId).collection('settings').doc('config');
  }
}
