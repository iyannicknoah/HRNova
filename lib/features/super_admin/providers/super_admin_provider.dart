import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/branch_model.dart';
import '../models/company_model.dart';
import '../models/payment_model.dart';

FirebaseFirestore get _fs => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

final companiesStreamProvider = StreamProvider<List<CompanyModel>>((ref) {
  return _fs
      .collection('companies')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(CompanyModel.fromDoc).toList());
});

final branchesProvider =
    StreamProvider.family<List<BranchModel>, String>((ref, companyId) {
  return _fs
      .collection('companies')
      .doc(companyId)
      .collection('branches')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => BranchModel.fromDoc(companyId, d)).toList());
});

final paymentsProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, companyId) {
  return _fs
      .collection('companies')
      .doc(companyId)
      .collection('payments')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(PaymentModel.fromDoc).toList());
});
