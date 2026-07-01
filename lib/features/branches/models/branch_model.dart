import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  const BranchModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.location = '',
    this.branchCode = '',
    this.branchHrAdminUid,
    this.branchHrAdminEmail,
    this.employeeCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String location;
  final String branchCode;
  final String? branchHrAdminUid;
  final String? branchHrAdminEmail;
  final int employeeCount;
  final bool isActive;
  final DateTime? createdAt;

  factory BranchModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return BranchModel(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      location: d['location'] as String? ?? '',
      branchCode: d['branchCode'] as String? ?? '',
      branchHrAdminUid: d['branchHrAdminUid'] as String?,
      branchHrAdminEmail: d['branchHrAdminEmail'] as String?,
      employeeCount: d['employeeCount'] as int? ?? 0,
      isActive: d['isActive'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'name': name,
    'location': location,
    'branchCode': branchCode,
    if (branchHrAdminUid != null) 'branchHrAdminUid': branchHrAdminUid,
    if (branchHrAdminEmail != null) 'branchHrAdminEmail': branchHrAdminEmail,
    'employeeCount': employeeCount,
    'isActive': isActive,
  };
}
