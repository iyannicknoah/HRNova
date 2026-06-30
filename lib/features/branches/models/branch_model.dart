class BranchModel {
  const BranchModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.location,
    required this.branchCode,
    this.branchHrAdminUid,
    this.employeeCount = 0,
    this.isActive = true,
    this.phone,
    this.email,
  });

  final String id;
  final String companyId;
  final String name;
  final String location;
  final String branchCode;
  final String? branchHrAdminUid;
  final int employeeCount;
  final bool isActive;
  final String? phone;
  final String? email;

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) {
    return BranchModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      branchCode: map['branchCode'] as String? ?? '',
      branchHrAdminUid: map['branchHrAdminUid'] as String?,
      employeeCount: map['employeeCount'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'location': location,
      'branchCode': branchCode,
      if (branchHrAdminUid != null) 'branchHrAdminUid': branchHrAdminUid,
      'employeeCount': employeeCount,
      'isActive': isActive,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }
}
