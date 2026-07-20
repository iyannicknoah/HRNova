import 'package:cloud_firestore/cloud_firestore.dart';

/// One applied deduction line, snapshotted onto the payslip at calculation
/// time so the payslip renders identically forever, even after the company
/// later changes its deduction settings.
class PayslipDeductionLine {
  const PayslipDeductionLine({
    required this.title,
    required this.percent,
    required this.amount,
  });

  final String title;
  final double percent; // 6 means 6%
  final double amount; // RWF, computed on adjusted gross

  factory PayslipDeductionLine.fromMap(Map<String, dynamic> m) =>
      PayslipDeductionLine(
        title: m['title'] as String? ?? '',
        percent: (m['percent'] as num?)?.toDouble() ?? 0,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'title': title, 'percent': percent, 'amount': amount};
}

/// Expanded payslip — all line items needed for PDF, exports, display.
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
    this.bankCode = '',
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
    // Company-defined deductions on adjustedGross (snapshotted lines)
    this.employeeDeductions = const [],
    this.employerContributions = const [],
    required this.paye,
    // Other deductions
    required this.loanDeductions,
    required this.extraDeductions,
    // Totals
    required this.totalDeductions,
    required this.netSalary,
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
  final String bankCode;
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

  // PAYE / deduction base
  final double adjustedGross; // totalEarnings - absentDeduction - lateDeduction

  // Company-defined deductions on adjustedGross, snapshotted at calc time
  final List<PayslipDeductionLine> employeeDeductions;
  final List<PayslipDeductionLine> employerContributions; // info only
  final double paye;

  double get totalEmployeeDeductionLines =>
      employeeDeductions.fold(0.0, (s, l) => s + l.amount);
  double get totalEmployerContributionLines =>
      employerContributions.fold(0.0, (s, l) => s + l.amount);

  // Other employee deductions
  final double loanDeductions;
  final double extraDeductions;
  final String? extraDeductionsDescription;

  // Summary
  final double totalDeductions; // deduction lines + paye + loans + extra
  final double netSalary;

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
      bankCode: map['bankCode'] as String? ?? '',
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
      employeeDeductions: _parseLines(map['employeeDeductions']) ??
          _legacyLines(map, employer: false),
      employerContributions: _parseLines(map['employerContributions']) ??
          _legacyLines(map, employer: true),
      paye: (map['paye'] as num?)?.toDouble() ?? 0,
      loanDeductions: (map['loanDeductions'] as num?)?.toDouble() ?? 0,
      extraDeductions: (map['extraDeductions'] as num?)?.toDouble() ??
          (map['deductions'] as num?)?.toDouble() ?? 0,
      extraDeductionsDescription: map['extraDeductionsDescription'] as String?,
      totalDeductions: (map['totalDeductions'] as num?)?.toDouble() ?? 0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0,
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
        'bankCode': bankCode,
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
        'employeeDeductions': employeeDeductions.map((l) => l.toMap()).toList(),
        'employerContributions': employerContributions.map((l) => l.toMap()).toList(),
        'totalEmployeeDeductionLines': totalEmployeeDeductionLines,
        'totalEmployerContributionLines': totalEmployerContributionLines,
        'paye': paye,
        'loanDeductions': loanDeductions,
        'extraDeductions': extraDeductions,
        if (extraDeductionsDescription != null)
          'extraDeductionsDescription': extraDeductionsDescription,
        'totalDeductions': totalDeductions,
        'netSalary': netSalary,
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

  static List<PayslipDeductionLine>? _parseLines(dynamic raw) {
    if (raw == null) return null;
    return (raw as List)
        .map((e) => PayslipDeductionLine.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Payslips saved before company-defined deductions existed stored fixed
  /// RSSB fields — rebuild them as lines so old payslips render unchanged.
  static List<PayslipDeductionLine> _legacyLines(Map<String, dynamic> map,
      {required bool employer}) {
    double d(String k) => (map[k] as num?)?.toDouble() ?? 0;
    final lines = employer
        ? [
            PayslipDeductionLine(title: 'RSSB Pension', percent: 6, amount: d('pensionEmployer')),
            PayslipDeductionLine(title: 'RSSB Maternity', percent: 0.3, amount: d('maternityEmployer')),
            PayslipDeductionLine(title: 'RSSB Occupational Hazard', percent: 2, amount: d('occupationalHazard')),
          ]
        : [
            PayslipDeductionLine(title: 'RSSB Pension', percent: 6, amount: d('pensionEmployee')),
            PayslipDeductionLine(title: 'RSSB Maternity', percent: 0.3, amount: d('maternityEmployee')),
          ];
    return lines.where((l) => l.amount > 0).toList();
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
    // Re-apply each snapshotted deduction percent on the new adjusted gross
    List<PayslipDeductionLine> reapply(List<PayslipDeductionLine> lines) => lines
        .map((l) => PayslipDeductionLine(
              title: l.title,
              percent: l.percent,
              amount: _r(newAdjustedGross * l.percent / 100),
            ))
        .toList();
    final newEmployeeLines = reapply(employeeDeductions);
    final newEmployerLines = reapply(employerContributions);
    final newEmployeeLinesTotal =
        newEmployeeLines.fold(0.0, (s, l) => s + l.amount);
    final newPaye = _calcPaye(newAdjustedGross);
    final newTotalDeductions =
        newEmployeeLinesTotal + newPaye + loanDeductions + newExtraDeductions;
    final newNet = newAdjustedGross - newTotalDeductions;
    final newEmployerCost = newAdjustedGross +
        newEmployerLines.fold(0.0, (s, l) => s + l.amount);

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
      bankCode: bankCode,
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
      employeeDeductions: newEmployeeLines,
      employerContributions: newEmployerLines,
      paye: newPaye,
      loanDeductions: loanDeductions,
      extraDeductions: newExtraDeductions,
      extraDeductionsDescription: extraDeductionsDescription ?? this.extraDeductionsDescription,
      totalDeductions: newTotalDeductions,
      netSalary: newNet,
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
    if (gross <= 100000) return _r((gross - 60000) * 0.10);
    if (gross <= 200000) return _r(4000 + (gross - 100000) * 0.20);
    return _r(24000 + (gross - 200000) * 0.30);
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
