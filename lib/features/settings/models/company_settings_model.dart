import 'package:cloud_firestore/cloud_firestore.dart';

class CompanySettings {
  final String workStartTime;
  final String workEndTime;
  final int gracePeriodMinutes;
  final int annualLeaveDays;
  final int sickLeaveDays;
  final int lateDeductionPerHourRwf;
  final int maxLateBeforeWarning;
  final String notificationMethod;
  final bool isOnboardingComplete;
  final List<String> workingDays;
  final List<String> departments;
  final String managerPhone;
  final String hrAdminPhone;
  final String managerEmail;
  final String hrAdminEmail;

  const CompanySettings({
    this.workStartTime = '08:00',
    this.workEndTime = '17:00',
    this.gracePeriodMinutes = 10,
    this.annualLeaveDays = 18,
    this.sickLeaveDays = 10,
    this.lateDeductionPerHourRwf = 500,
    this.maxLateBeforeWarning = 3,
    this.notificationMethod = 'both',
    this.isOnboardingComplete = false,
    this.workingDays = const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    this.departments = const [],
    this.managerPhone = '',
    this.hrAdminPhone = '',
    this.managerEmail = '',
    this.hrAdminEmail = '',
  });

  factory CompanySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return CompanySettings(
      workStartTime: data['workStartTime'] as String? ?? '08:00',
      workEndTime: data['workEndTime'] as String? ?? '17:00',
      gracePeriodMinutes: data['gracePeriodMinutes'] as int? ?? 10,
      annualLeaveDays: data['annualLeaveDays'] as int? ?? 18,
      sickLeaveDays: data['sickLeaveDays'] as int? ?? 10,
      lateDeductionPerHourRwf: data['lateDeductionPerHourRwf'] as int? ?? 500,
      maxLateBeforeWarning: data['maxLateBeforeWarning'] as int? ?? 3,
      notificationMethod: data['notificationMethod'] as String? ?? 'both',
      isOnboardingComplete: data['isOnboardingComplete'] as bool? ?? false,
      workingDays: List<String>.from(data['workingDays'] ?? ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']),
      departments: List<String>.from(data['departments'] ?? []),
      managerPhone: data['managerPhone'] as String? ?? '',
      hrAdminPhone: data['hrAdminPhone'] as String? ?? '',
      managerEmail: data['managerEmail'] as String? ?? '',
      hrAdminEmail: data['hrAdminEmail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'gracePeriodMinutes': gracePeriodMinutes,
      'annualLeaveDays': annualLeaveDays,
      'sickLeaveDays': sickLeaveDays,
      'lateDeductionPerHourRwf': lateDeductionPerHourRwf,
      'maxLateBeforeWarning': maxLateBeforeWarning,
      'notificationMethod': notificationMethod,
      'isOnboardingComplete': isOnboardingComplete,
      'workingDays': workingDays,
      'departments': departments,
      'managerPhone': managerPhone,
      'hrAdminPhone': hrAdminPhone,
      'managerEmail': managerEmail,
      'hrAdminEmail': hrAdminEmail,
    };
  }

  CompanySettings copyWith({
    String? workStartTime,
    String? workEndTime,
    int? gracePeriodMinutes,
    int? annualLeaveDays,
    int? sickLeaveDays,
    int? lateDeductionPerHourRwf,
    int? maxLateBeforeWarning,
    String? notificationMethod,
    bool? isOnboardingComplete,
    List<String>? workingDays,
    List<String>? departments,
    String? managerPhone,
    String? hrAdminPhone,
    String? managerEmail,
    String? hrAdminEmail,
  }) {
    return CompanySettings(
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      annualLeaveDays: annualLeaveDays ?? this.annualLeaveDays,
      sickLeaveDays: sickLeaveDays ?? this.sickLeaveDays,
      lateDeductionPerHourRwf: lateDeductionPerHourRwf ?? this.lateDeductionPerHourRwf,
      maxLateBeforeWarning: maxLateBeforeWarning ?? this.maxLateBeforeWarning,
      notificationMethod: notificationMethod ?? this.notificationMethod,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      workingDays: workingDays ?? this.workingDays,
      departments: departments ?? this.departments,
      managerPhone: managerPhone ?? this.managerPhone,
      hrAdminPhone: hrAdminPhone ?? this.hrAdminPhone,
      managerEmail: managerEmail ?? this.managerEmail,
      hrAdminEmail: hrAdminEmail ?? this.hrAdminEmail,
    );
  }
}
