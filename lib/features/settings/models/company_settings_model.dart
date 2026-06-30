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
    this.lateThresholdMinutes = 15,
    this.workingDaysPerWeek = 5,
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
  final String workStartTime;
  final String workEndTime;
  final int lateThresholdMinutes;
  final int workingDaysPerWeek;
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
  final bool enableWhatsappLeave;
  final bool enableSelfieAttendance;
  final bool enableAiReports;

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
      lateThresholdMinutes: map['lateThresholdMinutes'] as int? ?? 15,
      workingDaysPerWeek: map['workingDaysPerWeek'] as int? ?? 5,
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

  Map<String, dynamic> toMap() {
    return {
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
      'lateThresholdMinutes': lateThresholdMinutes,
      'workingDaysPerWeek': workingDaysPerWeek,
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
  }
}
