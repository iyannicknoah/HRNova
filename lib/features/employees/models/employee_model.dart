import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.companyId,
    required this.firstName,
    required this.lastName,
    required this.department,
    required this.jobTitle,
    required this.contractType,
    required this.salaryType,
    required this.startDate,
    required this.status,
    this.email = '',
    this.phone = '',
    this.nationalId = '',
    this.emergencyContact = '',
    this.gender = '',
    this.dateOfBirth,
    this.endDate,
    this.branchId,
    this.role = 'employee',
    this.salaryAmount = 0,
    this.dailyRate = 0,
    this.hourlyRate = 0,
    this.transportAllowance = 0,
    this.housingAllowance = 0,
    this.bankAccount = '',
    this.bankCode = '',
    this.rssbNumber = '',
    this.profilePhotoUrl,
    this.qrCode,
    this.leaveBalances = const {'annual': 18, 'sick': 10, 'maternity': 84, 'paternity': 4},
    this.loans = const [],
    this.notes,
    this.createdAt,
    this.initialPassword,
    this.profileComplete = true,
  });

  final String id;
  final String companyId;
  final String firstName;
  final String lastName;
  final String department;
  final String jobTitle;
  final String contractType;
  final String salaryType;
  final DateTime startDate;
  final String status;
  final String email;
  final String phone;
  final String nationalId;
  final String emergencyContact;
  /// 'male' or 'female' — drives maternity/paternity leave eligibility.
  /// Empty when not yet set.
  final String gender;
  final DateTime? dateOfBirth;
  final DateTime? endDate;
  final String? branchId;
  final String role;
  final double salaryAmount;
  final double dailyRate;
  final double hourlyRate;
  final double transportAllowance;
  final double housingAllowance;
  final String bankAccount;
  final String bankCode;
  final String rssbNumber;
  final String? profilePhotoUrl;
  final String? qrCode;
  final Map<String, dynamic> leaveBalances;
  final List<dynamic> loans;
  final String? notes;
  final DateTime? createdAt;
  final String? initialPassword;
  final bool profileComplete;

  String get fullName => '$firstName $lastName';
  bool get isActive => status == 'active';

  // Effective gross salary regardless of type
  double get grossSalary {
    return switch (salaryType) {
      'daily_rate'  => dailyRate,
      'hourly_rate' => hourlyRate,
      _             => salaryAmount,
    };
  }

  factory EmployeeModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EmployeeModel(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      department: d['department'] as String? ?? '',
      jobTitle: d['jobTitle'] as String? ?? d['position'] as String? ?? '',
      contractType: d['contractType'] as String? ?? 'permanent',
      salaryType: d['salaryType'] as String? ?? 'fixed_monthly',
      startDate: _toDate(d['startDate']) ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      nationalId: d['nationalId'] as String? ?? '',
      emergencyContact: d['emergencyContact'] as String? ?? '',
      gender: d['gender'] as String? ?? '',
      dateOfBirth: _toDate(d['dateOfBirth']),
      endDate: _toDate(d['endDate']),
      branchId: d['branchId'] as String?,
      role: d['role'] as String? ?? 'employee',
      salaryAmount: (d['salaryAmount'] as num?)?.toDouble() ?? (d['grossSalary'] as num?)?.toDouble() ?? 0,
      dailyRate: (d['dailyRate'] as num?)?.toDouble() ?? 0,
      hourlyRate: (d['hourlyRate'] as num?)?.toDouble() ?? 0,
      transportAllowance: (d['transportAllowance'] as num?)?.toDouble() ?? 0,
      housingAllowance: (d['housingAllowance'] as num?)?.toDouble() ?? 0,
      bankAccount: d['bankAccount'] as String? ?? d['bankAccountNumber'] as String? ?? '',
      bankCode: d['bankCode'] as String? ?? '',
      rssbNumber: d['rssbNumber'] as String? ?? '',
      profilePhotoUrl: d['profilePhotoUrl'] as String?,
      qrCode: d['qrCode'] as String?,
      leaveBalances: (d['leaveBalances'] as Map?)?.cast<String, dynamic>() ?? const {'annual': 18, 'sick': 10, 'maternity': 84, 'paternity': 4},
      loans: (d['loans'] as List?) ?? const [],
      notes: d['notes'] as String?,
      createdAt: _toDate(d['createdAt']),
      initialPassword: d['initialPassword'] as String?,
      profileComplete: d['profileComplete'] as bool? ?? true,
    );
  }

  factory EmployeeModel.fromMap(String id, Map<String, dynamic> d) {
    return EmployeeModel(
      id: id,
      companyId: d['companyId'] as String? ?? '',
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      department: d['department'] as String? ?? '',
      jobTitle: d['jobTitle'] as String? ?? d['position'] as String? ?? '',
      contractType: d['contractType'] as String? ?? 'permanent',
      salaryType: d['salaryType'] as String? ?? 'fixed_monthly',
      startDate: _toDate(d['startDate']) ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      nationalId: d['nationalId'] as String? ?? '',
      emergencyContact: d['emergencyContact'] as String? ?? '',
      gender: d['gender'] as String? ?? '',
      dateOfBirth: _toDate(d['dateOfBirth']),
      endDate: _toDate(d['endDate']),
      branchId: d['branchId'] as String?,
      role: d['role'] as String? ?? 'employee',
      salaryAmount: (d['salaryAmount'] as num?)?.toDouble() ?? (d['grossSalary'] as num?)?.toDouble() ?? 0,
      dailyRate: (d['dailyRate'] as num?)?.toDouble() ?? 0,
      hourlyRate: (d['hourlyRate'] as num?)?.toDouble() ?? 0,
      transportAllowance: (d['transportAllowance'] as num?)?.toDouble() ?? 0,
      housingAllowance: (d['housingAllowance'] as num?)?.toDouble() ?? 0,
      bankAccount: d['bankAccount'] as String? ?? d['bankAccountNumber'] as String? ?? '',
      bankCode: d['bankCode'] as String? ?? '',
      rssbNumber: d['rssbNumber'] as String? ?? '',
      profilePhotoUrl: d['profilePhotoUrl'] as String?,
      qrCode: d['qrCode'] as String?,
      leaveBalances: (d['leaveBalances'] as Map?)?.cast<String, dynamic>() ?? const {'annual': 18, 'sick': 10, 'maternity': 84, 'paternity': 4},
      loans: (d['loans'] as List?) ?? const [],
      notes: d['notes'] as String?,
      createdAt: _toDate(d['createdAt']),
      initialPassword: d['initialPassword'] as String?,
      profileComplete: d['profileComplete'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'firstName': firstName,
    'lastName': lastName,
    'department': department,
    'jobTitle': jobTitle,
    'contractType': contractType,
    'salaryType': salaryType,
    'startDate': startDate.toIso8601String(),
    'status': status,
    'email': email,
    'phone': phone,
    'nationalId': nationalId,
    'emergencyContact': emergencyContact,
    'gender': gender,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (branchId != null) 'branchId': branchId,
    'role': role,
    'salaryAmount': salaryAmount,
    'dailyRate': dailyRate,
    'hourlyRate': hourlyRate,
    'transportAllowance': transportAllowance,
    'housingAllowance': housingAllowance,
    'bankAccount': bankAccount,
    'bankCode': bankCode,
    'rssbNumber': rssbNumber,
    if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    if (qrCode != null) 'qrCode': qrCode,
    'leaveBalances': leaveBalances,
    'loans': loans,
    if (notes != null) 'notes': notes,
    'profileComplete': profileComplete,
  };

  EmployeeModel copyWith({
    String? firstName, String? lastName, String? department, String? jobTitle,
    String? contractType, String? salaryType, DateTime? startDate, String? status,
    String? email, String? phone, String? nationalId, String? emergencyContact, String? gender,
    DateTime? dateOfBirth, DateTime? endDate, String? branchId, String? role,
    double? salaryAmount, double? dailyRate, double? hourlyRate,
    double? transportAllowance, double? housingAllowance, String? bankAccount,
    String? bankCode, String? rssbNumber, String? profilePhotoUrl, String? qrCode,
    Map<String, dynamic>? leaveBalances, List<dynamic>? loans, String? notes,
    bool? profileComplete,
  }) =>
      EmployeeModel(
        id: id, companyId: companyId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        department: department ?? this.department,
        jobTitle: jobTitle ?? this.jobTitle,
        contractType: contractType ?? this.contractType,
        salaryType: salaryType ?? this.salaryType,
        startDate: startDate ?? this.startDate,
        status: status ?? this.status,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        nationalId: nationalId ?? this.nationalId,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        endDate: endDate ?? this.endDate,
        branchId: branchId ?? this.branchId,
        role: role ?? this.role,
        salaryAmount: salaryAmount ?? this.salaryAmount,
        dailyRate: dailyRate ?? this.dailyRate,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        transportAllowance: transportAllowance ?? this.transportAllowance,
        housingAllowance: housingAllowance ?? this.housingAllowance,
        bankAccount: bankAccount ?? this.bankAccount,
        bankCode: bankCode ?? this.bankCode,
        rssbNumber: rssbNumber ?? this.rssbNumber,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
        qrCode: qrCode ?? this.qrCode,
        leaveBalances: leaveBalances ?? this.leaveBalances,
        loans: loans ?? this.loans,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        profileComplete: profileComplete ?? this.profileComplete,
      );

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
