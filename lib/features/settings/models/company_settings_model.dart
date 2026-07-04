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
    this.workingDays = const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    this.workingDaysPerWeek = 5,
    this.annualLeaveDays = 18,
    this.sickLeaveDays = 10,
    this.lateDeductionPerHourRwf = 500,
    this.maxLateBeforeWarning = 3,
    this.salaryPaymentDay = 28,
    this.overtimeMultiplier = 1.5,
    this.transportAllowanceRwf = 0,
    this.housingAllowanceRwf = 0,
    this.notificationMethod = 'email',
    this.isOnboardingComplete = false,
    this.departments = const [],
    this.performanceCriteria = PerformanceCriterion.defaults,
    this.managerPhone = '',
    this.hrAdminPhone = '',
    this.guardPhone = '',
    this.managerEmail = '',
    this.hrAdminEmail = '',
    this.guardModeEnabled = true,
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
  final List<String> workingDays;
  final int workingDaysPerWeek;

  // Leave policy
  final int annualLeaveDays;
  final int sickLeaveDays;

  // Payroll rules
  final int lateDeductionPerHourRwf;
  final int maxLateBeforeWarning;
  final int salaryPaymentDay;
  final double overtimeMultiplier;
  final int transportAllowanceRwf;
  final int housingAllowanceRwf;

  // Notifications & contacts
  final String notificationMethod;
  final String managerPhone;
  final String hrAdminPhone;
  final String guardPhone;
  final String managerEmail;
  final String hrAdminEmail;

  // Feature flags
  final bool isOnboardingComplete;
  final bool guardModeEnabled;
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
      workingDays: (map['workingDays'] as List?)?.cast<String>() ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      workingDaysPerWeek: map['workingDaysPerWeek'] as int? ?? 5,
      annualLeaveDays: map['annualLeaveDays'] as int? ?? 18,
      sickLeaveDays: map['sickLeaveDays'] as int? ?? 10,
      lateDeductionPerHourRwf: map['lateDeductionPerHourRwf'] as int? ?? 500,
      maxLateBeforeWarning: map['maxLateBeforeWarning'] as int? ?? 3,
      salaryPaymentDay: map['salaryPaymentDay'] as int? ?? 28,
      overtimeMultiplier: (map['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      transportAllowanceRwf: map['transportAllowanceRwf'] as int? ?? 0,
      housingAllowanceRwf: map['housingAllowanceRwf'] as int? ?? 0,
      notificationMethod: map['notificationMethod'] as String? ?? 'email',
      isOnboardingComplete: map['isOnboardingComplete'] as bool? ?? false,
      departments: (map['departments'] as List?)?.cast<String>() ?? const [],
      performanceCriteria: () {
        final raw = map['performanceCriteria'];
        if (raw == null || (raw as List).isEmpty) return PerformanceCriterion.defaults;
        final first = (raw as List).first;
        if (first is String) {
          // Legacy: just names, use default weights
          return PerformanceCriterion.defaults;
        }
        return raw
            .map((e) => PerformanceCriterion.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }(),
      managerPhone: map['managerPhone'] as String? ?? '',
      hrAdminPhone: map['hrAdminPhone'] as String? ?? '',
      guardPhone: map['guardPhone'] as String? ?? '',
      managerEmail: map['managerEmail'] as String? ?? '',
      hrAdminEmail: map['hrAdminEmail'] as String? ?? '',
      guardModeEnabled: map['guardModeEnabled'] as bool? ?? true,
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
    'workingDays': workingDays,
    'workingDaysPerWeek': workingDaysPerWeek,
    'annualLeaveDays': annualLeaveDays,
    'sickLeaveDays': sickLeaveDays,
    'lateDeductionPerHourRwf': lateDeductionPerHourRwf,
    'maxLateBeforeWarning': maxLateBeforeWarning,
    'salaryPaymentDay': salaryPaymentDay,
    'overtimeMultiplier': overtimeMultiplier,
    'transportAllowanceRwf': transportAllowanceRwf,
    'housingAllowanceRwf': housingAllowanceRwf,
    'notificationMethod': notificationMethod,
    'isOnboardingComplete': isOnboardingComplete,
    'departments': departments,
    'performanceCriteria': performanceCriteria.map((c) => c.toMap()).toList(),
    'managerPhone': managerPhone,
    'hrAdminPhone': hrAdminPhone,
    'guardPhone': guardPhone,
    'managerEmail': managerEmail,
    'hrAdminEmail': hrAdminEmail,
    'guardModeEnabled': guardModeEnabled,
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
    int? salaryPaymentDay,
    double? overtimeMultiplier,
    int? transportAllowanceRwf,
    int? housingAllowanceRwf,
    String? notificationMethod,
    bool? isOnboardingComplete,
    List<String>? departments,
    List<PerformanceCriterion>? performanceCriteria,
    String? managerPhone,
    String? hrAdminPhone,
    String? guardPhone,
    String? managerEmail,
    String? hrAdminEmail,
    bool? guardModeEnabled,
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
        salaryPaymentDay: salaryPaymentDay ?? this.salaryPaymentDay,
        overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
        transportAllowanceRwf: transportAllowanceRwf ?? this.transportAllowanceRwf,
        housingAllowanceRwf: housingAllowanceRwf ?? this.housingAllowanceRwf,
        notificationMethod: notificationMethod ?? this.notificationMethod,
        isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
        departments: departments ?? this.departments,
        performanceCriteria: performanceCriteria ?? this.performanceCriteria,
        managerPhone: managerPhone ?? this.managerPhone,
        hrAdminPhone: hrAdminPhone ?? this.hrAdminPhone,
        guardPhone: guardPhone ?? this.guardPhone,
        managerEmail: managerEmail ?? this.managerEmail,
        hrAdminEmail: hrAdminEmail ?? this.hrAdminEmail,
        guardModeEnabled: guardModeEnabled ?? this.guardModeEnabled,
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
