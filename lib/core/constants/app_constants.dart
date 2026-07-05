class AppConstants {
  AppConstants._();

  static const String appName = 'HRNova';
  static const String appTagline = 'Your HR Team, Supercharged';
  static const String backendBaseUrl = 'http://localhost:3000';

  // Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleHrAdmin = 'hr_admin';
  static const String roleGroupHrAdmin = 'group_hr_admin';
  static const String roleBranchHrAdmin = 'branch_hr_admin';
  static const String roleFinanceManager = 'finance_manager';
  static const String roleManager = 'manager';
  static const String roleGuard = 'guard';
  static const String roleDirector = 'director';
  static const String roleEmployee = 'employee';

  static const List<String> roles = [
    roleSuperAdmin,
    roleHrAdmin,
    roleGroupHrAdmin,
    roleBranchHrAdmin,
    roleFinanceManager,
    roleManager,
    roleGuard,
    roleDirector,
    roleEmployee,
  ];

  // Company types
  static const String companySingle = 'single';
  static const String companyMultiBranch = 'multi_branch';

  // Leave types
  static const String leaveTypeAnnual = 'annual';
  static const String leaveTypeSick = 'sick';
  static const String leaveTypeMaternity = 'maternity';
  static const String leaveTypePaternity = 'paternity';
  static const String leaveTypeUnpaid = 'unpaid';
  static const String leaveTypeEmergency = 'emergency';
  static const String leaveTypeCompassionate = 'compassionate';

  static const List<String> leaveTypes = [
    leaveTypeAnnual,
    leaveTypeSick,
    leaveTypeMaternity,
    leaveTypePaternity,
    leaveTypeUnpaid,
    leaveTypeEmergency,
    leaveTypeCompassionate,
  ];

  // Leave sources
  static const String leaveSourceMobile = 'mobile';
  static const String leaveSourceWhatsapp = 'whatsapp';
  static const String leaveSourceManual = 'manual';

  static const List<String> leaveSources = [
    leaveSourceMobile,
    leaveSourceWhatsapp,
    leaveSourceManual,
  ];

  // Contract types
  static const String contractTypePermanent = 'permanent';
  static const String contractTypeFixedTerm = 'fixed_term';
  static const String contractTypeProbation = 'probation';
  static const String contractTypePartTime = 'part_time';

  static const List<String> contractTypes = [
    contractTypePermanent,
    contractTypeFixedTerm,
    contractTypeProbation,
    contractTypePartTime,
  ];

  // Salary types
  static const String salaryTypeFixedMonthly = 'fixed_monthly';
  static const String salaryTypeDailyRate = 'daily_rate';
  static const String salaryTypeHourlyRate = 'hourly_rate';

  static const List<String> salaryTypes = [
    salaryTypeFixedMonthly,
    salaryTypeDailyRate,
    salaryTypeHourlyRate,
  ];

  // Verification types
  static const String verificationGuardMode = 'guard_mode';
  static const String verificationManual = 'manual';
  static const String verificationSelfie = 'selfie';

  static const List<String> verificationTypes = [
    verificationGuardMode,
    verificationManual,
    verificationSelfie,
  ];

  // Rwanda public holidays (MM-DD)
  static const List<String> rwandaHolidays = [
    '01-01', // New Year's Day
    '01-02', // Day after New Year's Day
    '02-01', // National Heroes Day
    '04-07', // Genocide Memorial Day
    '05-01', // Labour Day
    '07-01', // Independence Day
    '07-04', // Liberation Day
    '08-15', // Assumption Day
    '12-25', // Christmas Day
    '12-26', // Boxing Day
  ];

  // Rwanda 2025 Tax Constants
  static const double pensionEmployeeRate = 0.06;
  static const double pensionEmployerRate = 0.06;
  static const double maternityEmployeeRate = 0.003;
  static const double maternityEmployerRate = 0.003;
  static const double occupationalHazardRate = 0.02;

  static const double payeTaxFreeMonthly = 60000.0;
  static const double payeBracket1Max = 100000.0;
  static const double payeBracket1Rate = 0.20;
  static const double payeBracket2Max = 200000.0;
  static const double payeBracket2Rate = 0.30;
  static const double payeBracket3Rate = 0.30;

  static const int rraDeadlineDay = 15;
  static const int maternityLeaveDays = 84;
  static const int paternityLeaveDays = 4;
  static const int sickLeaveDays = 10;

  // Annual leave entitlement (Rwanda Labour Law)
  static const int annualLeaveDaysPerYear = 18;
}
