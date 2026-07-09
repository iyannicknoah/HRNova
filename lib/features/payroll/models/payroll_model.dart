import 'package:cloud_firestore/cloud_firestore.dart';

/// Expanded payslip — all line items needed for PDF, RRA/RSSB exports, display.
class PayslipModel {
  const PayslipModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.payrollMonth,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.department,
    required this.nationalId,
    required this.rssbNumber,
    required this.bankAccountNumber,
    this.branchId,
    // Earnings
    required this.baseSalary,
    required this.transportAllowance,
    required this.housingAllowance,
    required this.bonuses,
    required this.totalEarnings,
    this.overtimeHours = 0,
    this.overtimePay = 0,
    // Deductions from gross
    required this.absentDays,
    required this.absentDeduction,
    required this.totalLateMinutes,
    required this.lateDeduction,
    // adjustedGross = totalEarnings - absentDeduction - lateDeduction
    required this.adjustedGross,
    // Statutory employee deductions on adjustedGross
    required this.pensionEmployee,
    required this.maternityEmployee,
    required this.totalEmployeeRssb,
    required this.paye,
    // Other deductions
    required this.loanDeductions,
    required this.extraDeductions,
    // Totals
    required this.totalDeductions,
    required this.netSalary,
    // Employer costs
    required this.pensionEmployer,
    required this.maternityEmployer,
    required this.occupationalHazard,
    required this.totalEmployerCost,
    // Metadata
    required this.workingDays,
    required this.presentDays,
    required this.status,
    this.bonusDescription,
    this.extraDeductionsDescription,
    this.notes,
    this.emailSent = false,
    this.createdAt,
    this.approvedBy,
    this.approvedAt,
  });

  final String id;
  final String employeeId;
  final String companyId;
  final String payrollMonth; // YYYY-MM

  // Identity
  final String firstName;
  final String lastName;
  final String position;
  final String department;
  final String nationalId;
  final String rssbNumber;
  final String bankAccountNumber;
  final String? branchId;

  // Earnings
  final double baseSalary;
  final double transportAllowance;
  final double housingAllowance;
  final double bonuses;
  final String? bonusDescription;
  final double totalEarnings; // baseSalary + transport + housing + bonuses + overtimePay
  final double overtimeHours;
  final double overtimePay;

  // Pre-statutory deductions
  final int absentDays;
  final double absentDeduction;
  final int totalLateMinutes;
  final double lateDeduction;

  // PAYE / RSSB base
  final double adjustedGross; // totalEarnings - absentDeduction - lateDeduction

  // Employee statutory deductions (on adjustedGross)
  final double pensionEmployee; // 6%
  final double maternityEmployee; // 0.3%
  final double totalEmployeeRssb;
  final double paye;

  // Other employee deductions
  final double loanDeductions;
  final double extraDeductions;
  final String? extraDeductionsDescription;

  // Summary
  final double totalDeductions; // rssb + paye + loans + extra
  final double netSalary;

  // Employer contributions (info only)
  final double pensionEmployer; // 6%
  final double maternityEmployer; // 0.3%
  final double occupationalHazard; // 2%
  final double totalEmployerCost;

  // Metadata
  final int workingDays;
  final int presentDays;
  final String status; // draft | approved
  final String? notes;
  final bool emailSent;
  final DateTime? createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  String get fullName => '$firstName $lastName';

  factory PayslipModel.fromMap(String id, Map<String, dynamic> map) {
    return PayslipModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? '',
      companyId: map['companyId'] as String? ?? '',
      payrollMonth: map['payrollMonth'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      position: map['position'] as String? ?? '',
      department: map['department'] as String? ?? '',
      nationalId: map['nationalId'] as String? ?? '',
      rssbNumber: map['rssbNumber'] as String? ?? '',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '',
      branchId: map['branchId'] as String?,
      baseSalary: (map['baseSalary'] as num?)?.toDouble() ?? 0,
      transportAllowance: (map['transportAllowance'] as num?)?.toDouble() ?? 0,
      housingAllowance: (map['housingAllowance'] as num?)?.toDouble() ?? 0,
      bonuses: (map['bonuses'] as num?)?.toDouble() ?? 0,
      bonusDescription: map['bonusDescription'] as String?,
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ??
          (map['grossSalary'] as num?)?.toDouble() ?? 0,
      overtimeHours: (map['overtimeHours'] as num?)?.toDouble() ?? 0,
      overtimePay: (map['overtimePay'] as num?)?.toDouble() ?? 0,
      absentDays: map['absentDays'] as int? ?? 0,
      absentDeduction: (map['absentDeduction'] as num?)?.toDouble() ?? 0,
      totalLateMinutes: map['totalLateMinutes'] as int? ?? 0,
      lateDeduction: (map['lateDeduction'] as num?)?.toDouble() ?? 0,
      adjustedGross: (map['adjustedGross'] as num?)?.toDouble() ??
          (map['grossSalary'] as num?)?.toDouble() ?? 0,
      pensionEmployee: (map['pensionEmployee'] as num?)?.toDouble() ?? 0,
      maternityEmployee: (map['maternityEmployee'] as num?)?.toDouble() ?? 0,
      totalEmployeeRssb: (map['totalEmployeeRssb'] as num?)?.toDouble() ??
          ((map['pensionEmployee'] as num?)?.toDouble() ?? 0) +
              ((map['maternityEmployee'] as num?)?.toDouble() ?? 0),
      paye: (map['paye'] as num?)?.toDouble() ?? 0,
      loanDeductions: (map['loanDeductions'] as num?)?.toDouble() ?? 0,
      extraDeductions: (map['extraDeductions'] as num?)?.toDouble() ??
          (map['deductions'] as num?)?.toDouble() ?? 0,
      extraDeductionsDescription: map['extraDeductionsDescription'] as String?,
      totalDeductions: (map['totalDeductions'] as num?)?.toDouble() ?? 0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0,
      pensionEmployer: (map['pensionEmployer'] as num?)?.toDouble() ?? 0,
      maternityEmployer: (map['maternityEmployer'] as num?)?.toDouble() ?? 0,
      occupationalHazard: (map['occupationalHazard'] as num?)?.toDouble() ?? 0,
      totalEmployerCost: (map['totalEmployerCost'] as num?)?.toDouble() ?? 0,
      workingDays: map['workingDays'] as int? ?? 0,
      presentDays: map['presentDays'] as int? ?? 0,
      status: map['status'] as String? ?? 'draft',
      notes: map['notes'] as String?,
      emailSent: map['emailSent'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']),
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null ? _parseDate(map['approvedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'companyId': companyId,
        'payrollMonth': payrollMonth,
        'firstName': firstName,
        'lastName': lastName,
        'position': position,
        'department': department,
        'nationalId': nationalId,
        'rssbNumber': rssbNumber,
        'bankAccountNumber': bankAccountNumber,
        if (branchId != null) 'branchId': branchId,
        'baseSalary': baseSalary,
        'transportAllowance': transportAllowance,
        'housingAllowance': housingAllowance,
        'bonuses': bonuses,
        if (bonusDescription != null) 'bonusDescription': bonusDescription,
        'totalEarnings': totalEarnings,
        'overtimeHours': overtimeHours,
        'overtimePay': overtimePay,
        'absentDays': absentDays,
        'absentDeduction': absentDeduction,
        'totalLateMinutes': totalLateMinutes,
        'lateDeduction': lateDeduction,
        'adjustedGross': adjustedGross,
        'grossSalary': adjustedGross, // compat key for RRA exports
        'pensionEmployee': pensionEmployee,
        'maternityEmployee': maternityEmployee,
        'totalEmployeeRssb': totalEmployeeRssb,
        'paye': paye,
        'loanDeductions': loanDeductions,
        'extraDeductions': extraDeductions,
        if (extraDeductionsDescription != null)
          'extraDeductionsDescription': extraDeductionsDescription,
        'totalDeductions': totalDeductions,
        'netSalary': netSalary,
        'pensionEmployer': pensionEmployer,
        'maternityEmployer': maternityEmployer,
        'occupationalHazard': occupationalHazard,
        'totalEmployerCost': totalEmployerCost,
        'workingDays': workingDays,
        'presentDays': presentDays,
        'status': status,
        if (notes != null) 'notes': notes,
        'emailSent': emailSent,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as Timestamp).toDate();
    } catch (_) {
      return null;
    }
  }

  PayslipModel copyWith({
    double? bonuses,
    String? bonusDescription,
    double? extraDeductions,
    String? extraDeductionsDescription,
    String? status,
    bool? emailSent,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    final newBonuses = bonuses ?? this.bonuses;
    final newExtraDeductions = extraDeductions ?? this.extraDeductions;
    final newTotalEarnings = baseSalary + transportAllowance + housingAllowance + newBonuses + overtimePay;
    final newAdjustedGross = newTotalEarnings - absentDeduction - lateDeduction;
    final newPensionEmp = _r(newAdjustedGross * 0.06);
    final newMaternityEmp = _r(newAdjustedGross * 0.003);
    final newTotalRssb = newPensionEmp + newMaternityEmp;
    final newPaye = _calcPaye(newAdjustedGross);
    final newTotalDeductions = newTotalRssb + newPaye + loanDeductions + newExtraDeductions;
    final newNet = newAdjustedGross - newTotalDeductions;
    final newPensionEmr = _r(newAdjustedGross * 0.06);
    final newMaternityEmr = _r(newAdjustedGross * 0.003);
    final newOccHazard = _r(newAdjustedGross * 0.02);
    final newEmployerCost = newAdjustedGross + newPensionEmr + newMaternityEmr + newOccHazard;

    return PayslipModel(
      id: id,
      employeeId: employeeId,
      companyId: companyId,
      payrollMonth: payrollMonth,
      firstName: firstName,
      lastName: lastName,
      position: position,
      department: department,
      nationalId: nationalId,
      rssbNumber: rssbNumber,
      bankAccountNumber: bankAccountNumber,
      branchId: branchId,
      baseSalary: baseSalary,
      transportAllowance: transportAllowance,
      housingAllowance: housingAllowance,
      bonuses: newBonuses,
      bonusDescription: bonusDescription ?? this.bonusDescription,
      totalEarnings: newTotalEarnings,
      overtimeHours: overtimeHours,
      overtimePay: overtimePay,
      absentDays: absentDays,
      absentDeduction: absentDeduction,
      totalLateMinutes: totalLateMinutes,
      lateDeduction: lateDeduction,
      adjustedGross: newAdjustedGross,
      pensionEmployee: newPensionEmp,
      maternityEmployee: newMaternityEmp,
      totalEmployeeRssb: newTotalRssb,
      paye: newPaye,
      loanDeductions: loanDeductions,
      extraDeductions: newExtraDeductions,
      extraDeductionsDescription: extraDeductionsDescription ?? this.extraDeductionsDescription,
      totalDeductions: newTotalDeductions,
      netSalary: newNet,
      pensionEmployer: newPensionEmr,
      maternityEmployer: newMaternityEmr,
      occupationalHazard: newOccHazard,
      totalEmployerCost: newEmployerCost,
      workingDays: workingDays,
      presentDays: presentDays,
      status: status ?? this.status,
      notes: notes,
      emailSent: emailSent ?? this.emailSent,
      createdAt: createdAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  static double _r(double v) => v.roundToDouble();

  static double _calcPaye(double gross) {
    if (gross <= 60000) return 0;
    if (gross <= 100000) return _r((gross - 60000) * 0.20);
    if (gross <= 200000) return _r(8000 + (gross - 100000) * 0.30);
    return _r(38000 + (gross - 200000) * 0.30);
  }
}

class PayrollRunModel {
  const PayrollRunModel({
    required this.companyId,
    required this.payrollMonth,
    required this.status,
    required this.totalEarnings,
    required this.totalGross,
    required this.totalNet,
    required this.totalPaye,
    required this.totalRssb,
    required this.totalEmployerCost,
    required this.employeeCount,
    required this.createdAt,
    this.branchId,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String companyId;
  final String payrollMonth;
  final String status; // draft | approved
  final double totalEarnings;
  final double totalGross; // adjustedGross sum
  final double totalNet;
  final double totalPaye;
  final double totalRssb;
  final double totalEmployerCost;
  final int employeeCount;
  final DateTime createdAt;
  final String? branchId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  factory PayrollRunModel.fromMap(Map<String, dynamic> map) {
    return PayrollRunModel(
      companyId: map['companyId'] as String? ?? '',
      payrollMonth: map['payrollMonth'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ??
          (map['totalGross'] as num?)?.toDouble() ?? 0,
      totalGross: (map['totalGross'] as num?)?.toDouble() ?? 0,
      totalNet: (map['totalNet'] as num?)?.toDouble() ?? 0,
      totalPaye: (map['totalPaye'] as num?)?.toDouble() ?? 0,
      totalRssb: (map['totalRssb'] as num?)?.toDouble() ?? 0,
      totalEmployerCost: (map['totalEmployerCost'] as num?)?.toDouble() ?? 0,
      employeeCount: map['employeeCount'] as int? ?? 0,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      branchId: map['branchId'] as String?,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null ? _parseDate(map['approvedAt']) : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'payrollMonth': payrollMonth,
        'status': status,
        'totalEarnings': totalEarnings,
        'totalGross': totalGross,
        'totalNet': totalNet,
        'totalPaye': totalPaye,
        'totalRssb': totalRssb,
        'totalEmployerCost': totalEmployerCost,
        'employeeCount': employeeCount,
        'createdAt': createdAt.toIso8601String(),
        if (branchId != null) 'branchId': branchId,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (notes != null) 'notes': notes,
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as Timestamp).toDate();
    } catch (_) {
      return null;
    }
  }
}
