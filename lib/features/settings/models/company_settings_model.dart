class PerformanceCriterion {
  const PerformanceCriterion({required this.name, required this.weight});
  final String name;
  final double weight;

  static const defaults = [
    PerformanceCriterion(name: 'Attendance and Punctuality', weight: 20),
    PerformanceCriterion(name: 'Quality of Work', weight: 25),
    PerformanceCriterion(name: 'Teamwork', weight: 20),
    PerformanceCriterion(name: 'Initiative', weight: 20),
    PerformanceCriterion(name: 'Communication', weight: 15),
  ];

  factory PerformanceCriterion.fromMap(Map<String, dynamic> m) =>
      PerformanceCriterion(
        name: m['name'] as String? ?? '',
        weight: (m['weight'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'name': name, 'weight': weight};
}

/// A company-defined percentage deduction applied on adjusted gross during
/// payroll. PAYE is statutory and never part of this list.
class DeductionRule {
  const DeductionRule({
    required this.title,
    required this.percent,
    required this.side,
    this.active = true,
  });

  final String title;
  final double percent; // 6 means 6%
  final String side; // 'employee' (reduces net) | 'employer' (company cost)
  final bool active;

  static const sideEmployee = 'employee';
  static const sideEmployer = 'employer';

  /// Standard Rwanda RSSB scheme — the pre-filled starting point every
  /// company gets, fully editable per company.
  static const rssbDefaults = [
    DeductionRule(title: 'RSSB Pension', percent: 6, side: sideEmployee),
    DeductionRule(title: 'RSSB Maternity', percent: 0.3, side: sideEmployee),
    DeductionRule(title: 'RSSB Pension', percent: 6, side: sideEmployer),
    DeductionRule(title: 'RSSB Maternity', percent: 0.3, side: sideEmployer),
    DeductionRule(title: 'RSSB Occupational Hazard', percent: 2, side: sideEmployer),
  ];

  factory DeductionRule.fromMap(Map<String, dynamic> m) => DeductionRule(
        title: m['title'] as String? ?? '',
        percent: (m['percent'] as num?)?.toDouble() ?? 0,
        side: m['side'] as String? ?? sideEmployee,
        active: m['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() =>
      {'title': title, 'percent': percent, 'side': side, 'active': active};

  DeductionRule copyWith({String? title, double? percent, String? side, bool? active}) =>
      DeductionRule(
        title: title ?? this.title,
        percent: percent ?? this.percent,
        side: side ?? this.side,
        active: active ?? this.active,
      );
}

class CompanySettingsModel {
  const CompanySettingsModel({
    required this.companyId,
    required this.companyName,
    this.industry = '',
    this.companyType = 'single',
    this.rraTinNumber,
    this.rssbNumber,
    this.logoUrl,
    this.primaryColor,
    this.companySlug,
    this.workStartTime = '08:00',
    this.workEndTime = '17:00',
    this.gracePeriodMinutes = 10,
    this.lateThresholdMinutes = 15,
    this.minimumHoursBeforeCheckout = 0,
    this.workingDays = const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    this.workingDaysPerWeek = 5,
    this.annualLeaveDays = 18,
    this.sickLeaveDays = 10,
    this.lateDeductionPerHourRwf = 500,
    this.maxLateBeforeWarning = 3,
    this.deductAbsentDays = false,
    this.salaryPaymentDay = 28,
    this.overtimeMultiplier = 1.5,
    this.transportAllowanceRwf = 0,
    this.housingAllowanceRwf = 0,
    this.deductions = DeductionRule.rssbDefaults,
    this.notificationMethod = 'email',
    this.isOnboardingComplete = false,
    this.departments = const [],
    this.performanceCriteria = PerformanceCriterion.defaults,
    this.managerPhone = '',
    this.hrAdminPhone = '',
    this.managerEmail = '',
    this.hrAdminEmail = '',
    this.directorEmail = '',
    this.directorPhone = '',
    this.rraExportEnabled = true,
    this.timezone = 'Africa/Kigali',
    this.currency = 'RWF',
    this.country = 'Rwanda',
    this.phone,
    this.email,
    this.address,
    this.website,
    this.brevoApiKey,
    this.openRouterApiKey,
    this.monthlyPrice = 0,
    this.status = 'active',
    this.enableWhatsappLeave = false,
    this.enableSelfieAttendance = false,
    this.enableAiReports = true,
  });

  final String companyId;
  final String companyName;
  final String industry;
  final String companyType;
  final String? rraTinNumber;
  final String? rssbNumber;
  final String? logoUrl;
  final String? primaryColor;
  final String? companySlug;

  // Work schedule
  final String workStartTime;
  final String workEndTime;
  final int gracePeriodMinutes;
  final int lateThresholdMinutes;
  /// Minimum hours an employee must work after checking in before they're
  /// allowed to check out. 0 disables the restriction.
  final double minimumHoursBeforeCheckout;
  final List<String> workingDays;
  final int workingDaysPerWeek;

  // Leave policy
  final int annualLeaveDays;
  final int sickLeaveDays;

  // Payroll rules
  final int lateDeductionPerHourRwf;
  final int maxLateBeforeWarning;
  /// When true, fixed-monthly employees lose one day's pay per unexcused
  /// absent day. Off by default — companies opt in.
  final bool deductAbsentDays;
  final int salaryPaymentDay;
  final double overtimeMultiplier;
  final int transportAllowanceRwf;
  final int housingAllowanceRwf;

  /// Company-defined percentage deductions (on adjusted gross). Companies
  /// that never saved the field get the standard RSSB scheme.
  final List<DeductionRule> deductions;

  List<DeductionRule> get activeEmployeeDeductions => deductions
      .where((d) => d.active && d.side == DeductionRule.sideEmployee)
      .toList();
  List<DeductionRule> get activeEmployerDeductions => deductions
      .where((d) => d.active && d.side == DeductionRule.sideEmployer)
      .toList();

  // Notifications & contacts
  final String notificationMethod;
  final String managerPhone;
  final String hrAdminPhone;
  final String managerEmail;
  final String hrAdminEmail;
  final String directorEmail;
  final String directorPhone;

  // Feature flags
  final bool isOnboardingComplete;
  final bool rraExportEnabled;
  final bool enableWhatsappLeave;
  final bool enableSelfieAttendance;
  final bool enableAiReports;

  // Lists
  final List<String> departments;
  final List<PerformanceCriterion> performanceCriteria;

  // Company info
  final String timezone;
  final String currency;
  final String country;
  final String? phone;
  final String? email;
  final String? address;
  final String? website;
  final String? brevoApiKey;
  final String? openRouterApiKey;
  final double monthlyPrice;
  final String status;

  factory CompanySettingsModel.fromMap(String companyId, Map<String, dynamic> map) {
    return CompanySettingsModel(
      companyId: companyId,
      companyName: map['companyName'] as String? ?? '',
      industry: map['industry'] as String? ?? '',
      companyType: map['companyType'] as String? ?? 'single',
      rraTinNumber: map['rraTinNumber'] as String?,
      rssbNumber: map['rssbNumber'] as String?,
      logoUrl: map['logoUrl'] as String?,
      primaryColor: map['primaryColor'] as String?,
      companySlug: map['companySlug'] as String?,
      workStartTime: map['workStartTime'] as String? ?? '08:00',
      workEndTime: map['workEndTime'] as String? ?? '17:00',
      gracePeriodMinutes: map['gracePeriodMinutes'] as int? ?? 10,
      lateThresholdMinutes: map['lateThresholdMinutes'] as int? ?? 15,
      minimumHoursBeforeCheckout: (map['minimumHoursBeforeCheckout'] as num?)?.toDouble() ?? 0,
      workingDays: (map['workingDays'] as List?)?.cast<String>() ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      workingDaysPerWeek: map['workingDaysPerWeek'] as int? ?? 5,
      annualLeaveDays: map['annualLeaveDays'] as int? ?? 18,
      sickLeaveDays: map['sickLeaveDays'] as int? ?? 10,
      lateDeductionPerHourRwf: map['lateDeductionPerHourRwf'] as int? ?? 500,
      maxLateBeforeWarning: map['maxLateBeforeWarning'] as int? ?? 3,
      deductAbsentDays: map['deductAbsentDays'] as bool? ?? false,
      salaryPaymentDay: map['salaryPaymentDay'] as int? ?? 28,
      overtimeMultiplier: (map['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      transportAllowanceRwf: map['transportAllowanceRwf'] as int? ?? 0,
      housingAllowanceRwf: map['housingAllowanceRwf'] as int? ?? 0,
      deductions: map['deductions'] == null
          ? DeductionRule.rssbDefaults
          : (map['deductions'] as List)
              .map((e) => DeductionRule.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
      notificationMethod: map['notificationMethod'] as String? ?? 'email',
      isOnboardingComplete: map['isOnboardingComplete'] as bool? ?? false,
      departments: (map['departments'] as List?)?.cast<String>() ?? const [],
      performanceCriteria: () {
        final raw = map['performanceCriteria'];
        if (raw == null || (raw as List).isEmpty) return PerformanceCriterion.defaults;
        final first = (raw as List).first;
        if (first is String) return PerformanceCriterion.defaults;
        return raw.map((e) => PerformanceCriterion.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      }(),
      managerPhone: map['managerPhone'] as String? ?? '',
      hrAdminPhone: map['hrAdminPhone'] as String? ?? '',
      managerEmail: map['managerEmail'] as String? ?? '',
      hrAdminEmail: map['hrAdminEmail'] as String? ?? '',
      directorEmail: map['directorEmail'] as String? ?? '',
      directorPhone: map['directorPhone'] as String? ?? '',
      rraExportEnabled: map['rraExportEnabled'] as bool? ?? true,
      timezone: map['timezone'] as String? ?? 'Africa/Kigali',
      currency: map['currency'] as String? ?? 'RWF',
      country: map['country'] as String? ?? 'Rwanda',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      website: map['website'] as String?,
      brevoApiKey: map['brevoApiKey'] as String?,
      openRouterApiKey: map['openRouterApiKey'] as String?,
      monthlyPrice: (map['monthlyPrice'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'active',
      enableWhatsappLeave: map['enableWhatsappLeave'] as bool? ?? false,
      enableSelfieAttendance: map['enableSelfieAttendance'] as bool? ?? false,
      enableAiReports: map['enableAiReports'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'companyName': companyName,
    'industry': industry,
    'companyType': companyType,
    if (rraTinNumber != null) 'rraTinNumber': rraTinNumber,
    if (rssbNumber != null) 'rssbNumber': rssbNumber,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (primaryColor != null) 'primaryColor': primaryColor,
    if (companySlug != null) 'companySlug': companySlug,
    'workStartTime': workStartTime,
    'workEndTime': workEndTime,
    'gracePeriodMinutes': gracePeriodMinutes,
    'lateThresholdMinutes': lateThresholdMinutes,
    'minimumHoursBeforeCheckout': minimumHoursBeforeCheckout,
    'workingDays': workingDays,
    'workingDaysPerWeek': workingDaysPerWeek,
    'annualLeaveDays': annualLeaveDays,
    'sickLeaveDays': sickLeaveDays,
    'lateDeductionPerHourRwf': lateDeductionPerHourRwf,
    'maxLateBeforeWarning': maxLateBeforeWarning,
    'deductAbsentDays': deductAbsentDays,
    'salaryPaymentDay': salaryPaymentDay,
    'overtimeMultiplier': overtimeMultiplier,
    'transportAllowanceRwf': transportAllowanceRwf,
    'housingAllowanceRwf': housingAllowanceRwf,
    'deductions': deductions.map((d) => d.toMap()).toList(),
    'notificationMethod': notificationMethod,
    'isOnboardingComplete': isOnboardingComplete,
    'departments': departments,
    'performanceCriteria': performanceCriteria.map((c) => c.toMap()).toList(),
    'managerPhone': managerPhone,
    'hrAdminPhone': hrAdminPhone,
    'managerEmail': managerEmail,
    'hrAdminEmail': hrAdminEmail,
    'directorEmail': directorEmail,
    'directorPhone': directorPhone,
    'rraExportEnabled': rraExportEnabled,
    'timezone': timezone,
    'currency': currency,
    'country': country,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (address != null) 'address': address,
    if (website != null) 'website': website,
    'monthlyPrice': monthlyPrice,
    'status': status,
    'enableWhatsappLeave': enableWhatsappLeave,
    'enableSelfieAttendance': enableSelfieAttendance,
    'enableAiReports': enableAiReports,
  };

  CompanySettingsModel copyWith({
    String? companyName,
    String? industry,
    String? companyType,
    String? rraTinNumber,
    String? workStartTime,
    String? workEndTime,
    int? gracePeriodMinutes,
    List<String>? workingDays,
    int? annualLeaveDays,
    int? sickLeaveDays,
    int? lateDeductionPerHourRwf,
    int? maxLateBeforeWarning,
    bool? deductAbsentDays,
    int? salaryPaymentDay,
    double? overtimeMultiplier,
    int? transportAllowanceRwf,
    int? housingAllowanceRwf,
    List<DeductionRule>? deductions,
    String? notificationMethod,
    bool? isOnboardingComplete,
    List<String>? departments,
    List<PerformanceCriterion>? performanceCriteria,
    String? managerPhone,
    String? hrAdminPhone,
    String? managerEmail,
    String? hrAdminEmail,
    String? directorEmail,
    String? directorPhone,
    bool? rraExportEnabled,
    String? phone,
    String? email,
    String? address,
  }) =>
      CompanySettingsModel(
        companyId: companyId,
        companyName: companyName ?? this.companyName,
        industry: industry ?? this.industry,
        companyType: companyType ?? this.companyType,
        rraTinNumber: rraTinNumber ?? this.rraTinNumber,
        rssbNumber: rssbNumber,
        logoUrl: logoUrl,
        primaryColor: primaryColor,
        companySlug: companySlug,
        workStartTime: workStartTime ?? this.workStartTime,
        workEndTime: workEndTime ?? this.workEndTime,
        gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
        lateThresholdMinutes: lateThresholdMinutes,
        workingDays: workingDays ?? this.workingDays,
        workingDaysPerWeek: workingDaysPerWeek,
        annualLeaveDays: annualLeaveDays ?? this.annualLeaveDays,
        sickLeaveDays: sickLeaveDays ?? this.sickLeaveDays,
        lateDeductionPerHourRwf: lateDeductionPerHourRwf ?? this.lateDeductionPerHourRwf,
        maxLateBeforeWarning: maxLateBeforeWarning ?? this.maxLateBeforeWarning,
        deductAbsentDays: deductAbsentDays ?? this.deductAbsentDays,
        salaryPaymentDay: salaryPaymentDay ?? this.salaryPaymentDay,
        overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
        transportAllowanceRwf: transportAllowanceRwf ?? this.transportAllowanceRwf,
        housingAllowanceRwf: housingAllowanceRwf ?? this.housingAllowanceRwf,
        deductions: deductions ?? this.deductions,
        notificationMethod: notificationMethod ?? this.notificationMethod,
        isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
        departments: departments ?? this.departments,
        performanceCriteria: performanceCriteria ?? this.performanceCriteria,
        managerPhone: managerPhone ?? this.managerPhone,
        hrAdminPhone: hrAdminPhone ?? this.hrAdminPhone,
        managerEmail: managerEmail ?? this.managerEmail,
        hrAdminEmail: hrAdminEmail ?? this.hrAdminEmail,
        directorEmail: directorEmail ?? this.directorEmail,
        directorPhone: directorPhone ?? this.directorPhone,
        rraExportEnabled: rraExportEnabled ?? this.rraExportEnabled,
        timezone: timezone,
        currency: currency,
        country: country,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        website: website,
        brevoApiKey: brevoApiKey,
        openRouterApiKey: openRouterApiKey,
        monthlyPrice: monthlyPrice,
        status: status,
        enableWhatsappLeave: enableWhatsappLeave,
        enableSelfieAttendance: enableSelfieAttendance,
        enableAiReports: enableAiReports,
      );
}
