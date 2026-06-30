class PayslipModel {
  const PayslipModel({
    required this.employeeId,
    required this.companyId,
    required this.payrollMonth,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.department,
    required this.grossSalary,
    required this.pensionEmployee,
    required this.pensionEmployer,
    required this.maternityEmployee,
    required this.maternityEmployer,
    required this.occupationalHazard,
    required this.paye,
    required this.netSalary,
    required this.totalEmployerCost,
    required this.workingDays,
    required this.presentDays,
    required this.status,
    this.bankName,
    this.bankAccountNumber,
    this.rssbNumber,
    this.allowances = 0,
    this.deductions = 0,
    this.notes,
  });

  final String employeeId;
  final String companyId;
  final String payrollMonth;
  final String firstName;
  final String lastName;
  final String position;
  final String department;
  final double grossSalary;
  final double pensionEmployee;
  final double pensionEmployer;
  final double maternityEmployee;
  final double maternityEmployer;
  final double occupationalHazard;
  final double paye;
  final double netSalary;
  final double totalEmployerCost;
  final int workingDays;
  final int presentDays;
  final String status;
  final String? bankName;
  final String? bankAccountNumber;
  final String? rssbNumber;
  final double allowances;
  final double deductions;
  final String? notes;

  String get fullName => '$firstName $lastName';

  factory PayslipModel.fromMap(Map<String, dynamic> map) {
    return PayslipModel(
      employeeId: map['employeeId'] as String? ?? '',
      companyId: map['companyId'] as String? ?? '',
      payrollMonth: map['payrollMonth'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      position: map['position'] as String? ?? '',
      department: map['department'] as String? ?? '',
      grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0,
      pensionEmployee: (map['pensionEmployee'] as num?)?.toDouble() ?? 0,
      pensionEmployer: (map['pensionEmployer'] as num?)?.toDouble() ?? 0,
      maternityEmployee: (map['maternityEmployee'] as num?)?.toDouble() ?? 0,
      maternityEmployer: (map['maternityEmployer'] as num?)?.toDouble() ?? 0,
      occupationalHazard: (map['occupationalHazard'] as num?)?.toDouble() ?? 0,
      paye: (map['paye'] as num?)?.toDouble() ?? 0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0,
      totalEmployerCost: (map['totalEmployerCost'] as num?)?.toDouble() ?? 0,
      workingDays: map['workingDays'] as int? ?? 0,
      presentDays: map['presentDays'] as int? ?? 0,
      status: map['status'] as String? ?? 'draft',
      bankName: map['bankName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      rssbNumber: map['rssbNumber'] as String?,
      allowances: (map['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (map['deductions'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'companyId': companyId,
      'payrollMonth': payrollMonth,
      'firstName': firstName,
      'lastName': lastName,
      'position': position,
      'department': department,
      'grossSalary': grossSalary,
      'pensionEmployee': pensionEmployee,
      'pensionEmployer': pensionEmployer,
      'maternityEmployee': maternityEmployee,
      'maternityEmployer': maternityEmployer,
      'occupationalHazard': occupationalHazard,
      'paye': paye,
      'netSalary': netSalary,
      'totalEmployerCost': totalEmployerCost,
      'workingDays': workingDays,
      'presentDays': presentDays,
      'status': status,
      'allowances': allowances,
      'deductions': deductions,
      if (bankName != null) 'bankName': bankName,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (rssbNumber != null) 'rssbNumber': rssbNumber,
      if (notes != null) 'notes': notes,
    };
  }
}

class PayrollRunModel {
  const PayrollRunModel({
    required this.companyId,
    required this.payrollMonth,
    required this.status,
    required this.totalGross,
    required this.totalNet,
    required this.totalPaye,
    required this.totalRssb,
    required this.totalEmployerCost,
    required this.employeeCount,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String companyId;
  final String payrollMonth;
  final String status;
  final double totalGross;
  final double totalNet;
  final double totalPaye;
  final double totalRssb;
  final double totalEmployerCost;
  final int employeeCount;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  factory PayrollRunModel.fromMap(Map<String, dynamic> map) {
    return PayrollRunModel(
      companyId: map['companyId'] as String? ?? '',
      payrollMonth: map['payrollMonth'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      totalGross: (map['totalGross'] as num?)?.toDouble() ?? 0,
      totalNet: (map['totalNet'] as num?)?.toDouble() ?? 0,
      totalPaye: (map['totalPaye'] as num?)?.toDouble() ?? 0,
      totalRssb: (map['totalRssb'] as num?)?.toDouble() ?? 0,
      totalEmployerCost: (map['totalEmployerCost'] as num?)?.toDouble() ?? 0,
      employeeCount: map['employeeCount'] as int? ?? 0,
      createdAt: _parseDate(map['createdAt']),
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null ? _parseDate(map['approvedAt']) : null,
      notes: map['notes'] as String?,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
