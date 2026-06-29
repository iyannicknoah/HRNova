class AppConstants {
  AppConstants._();

  static const String appName = 'HRNova';
  static const String appTagline = 'Your HR Team, Supercharged';
  static const String backendBaseUrl = 'http://localhost:3000';

  // User Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleHrAdmin = 'hr_admin';
  static const String roleManager = 'manager';
  static const String roleEmployee = 'employee';
  
  static const List<String> roles = [
    roleSuperAdmin,
    roleHrAdmin,
    roleManager,
    roleEmployee,
  ];

  // Leave Types
  static const String leaveTypeAnnual = 'annual';
  static const String leaveTypeSick = 'sick';
  static const String leaveTypeMaternity = 'maternity';
  static const String leaveTypePaternity = 'paternity';
  static const String leaveTypeUnpaid = 'unpaid';
  static const String leaveTypeEmergency = 'emergency';

  static const List<String> leaveTypes = [
    leaveTypeAnnual,
    leaveTypeSick,
    leaveTypeMaternity,
    leaveTypePaternity,
    leaveTypeUnpaid,
    leaveTypeEmergency,
  ];

  // Contract Types
  static const String contractTypePermanent = 'permanent';
  static const String contractTypeFixedTerm = 'fixed_term';
  static const String contractTypeProbation = 'probation';

  static const List<String> contractTypes = [
    contractTypePermanent,
    contractTypeFixedTerm,
    contractTypeProbation,
  ];

  // Salary Types
  static const String salaryTypeFixedMonthly = 'fixed_monthly';
  static const String salaryTypeDailyRate = 'daily_rate';
  static const String salaryTypeHourlyRate = 'hourly_rate';

  static const List<String> salaryTypes = [
    salaryTypeFixedMonthly,
    salaryTypeDailyRate,
    salaryTypeHourlyRate,
  ];

  // Rwanda Public Holidays (MM-DD format)
  static const List<String> rwandaHolidays = [
    '01-01', // New Year's Day
    '01-02', // Day after New Year's Day
    '02-01', // National Heroes Day
    '04-07', // Genocide Memorial Day
    '05-01', // Labor Day
    '07-01', // Independence Day
    '07-04', // Liberation Day
    '08-15', // Assumption Day
    '12-25', // Christmas Day
    '12-26', // Boxing Day
  ];
}
