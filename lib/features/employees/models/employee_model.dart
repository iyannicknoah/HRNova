class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.companyId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.position,
    required this.contractType,
    required this.salaryType,
    required this.grossSalary,
    required this.status,
    required this.startDate,
    this.branchId,
    this.profilePhotoUrl,
    this.qrCode,
    this.nationalId,
    this.passportNumber,
    this.rssbNumber,
    this.bankAccountNumber,
    this.bankName,
    this.managerId,
    this.endDate,
    this.annualLeaveBalance = 18,
    this.sickLeaveBalance = 21,
    this.notes,
  });

  final String id;
  final String companyId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String department;
  final String position;
  final String contractType;
  final String salaryType;
  final double grossSalary;
  final String status;
  final DateTime startDate;
  final String? branchId;
  final String? profilePhotoUrl;
  final String? qrCode;
  final String? nationalId;
  final String? passportNumber;
  final String? rssbNumber;
  final String? bankAccountNumber;
  final String? bankName;
  final String? managerId;
  final DateTime? endDate;
  final int annualLeaveBalance;
  final int sickLeaveBalance;
  final String? notes;

  String get fullName => '$firstName $lastName';

  factory EmployeeModel.fromMap(String id, Map<String, dynamic> map) {
    return EmployeeModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'employee',
      department: map['department'] as String? ?? '',
      position: map['position'] as String? ?? '',
      contractType: map['contractType'] as String? ?? 'permanent',
      salaryType: map['salaryType'] as String? ?? 'fixed_monthly',
      grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'active',
      startDate: _parseDate(map['startDate']),
      branchId: map['branchId'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      qrCode: map['qrCode'] as String?,
      nationalId: map['nationalId'] as String?,
      passportNumber: map['passportNumber'] as String?,
      rssbNumber: map['rssbNumber'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      bankName: map['bankName'] as String?,
      managerId: map['managerId'] as String?,
      endDate: map['endDate'] != null ? _parseDate(map['endDate']) : null,
      annualLeaveBalance: map['annualLeaveBalance'] as int? ?? 18,
      sickLeaveBalance: map['sickLeaveBalance'] as int? ?? 21,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'position': position,
      'contractType': contractType,
      'salaryType': salaryType,
      'grossSalary': grossSalary,
      'status': status,
      'startDate': startDate.toIso8601String(),
      if (branchId != null) 'branchId': branchId,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (qrCode != null) 'qrCode': qrCode,
      if (nationalId != null) 'nationalId': nationalId,
      if (passportNumber != null) 'passportNumber': passportNumber,
      if (rssbNumber != null) 'rssbNumber': rssbNumber,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (bankName != null) 'bankName': bankName,
      if (managerId != null) 'managerId': managerId,
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'annualLeaveBalance': annualLeaveBalance,
      'sickLeaveBalance': sickLeaveBalance,
      if (notes != null) 'notes': notes,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      // Firestore Timestamp
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
