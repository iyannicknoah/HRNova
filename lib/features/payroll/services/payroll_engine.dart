import '../../employees/models/employee_model.dart';
import '../models/payroll_model.dart';
import '../../../core/constants/app_constants.dart';

class PayrollEngine {
  PayrollEngine._();

  // Rwanda 2025 PAYE — taxable = gross (RSSB does NOT reduce PAYE base)
  static double calculatePaye(double grossSalary) {
    if (grossSalary <= AppConstants.payeTaxFreeMonthly) return 0;

    if (grossSalary <= AppConstants.payeBracket1Max) {
      return (grossSalary - AppConstants.payeTaxFreeMonthly) * AppConstants.payeBracket1Rate;
    }

    if (grossSalary <= AppConstants.payeBracket2Max) {
      return 8000 +
          (grossSalary - AppConstants.payeBracket1Max) * AppConstants.payeBracket2Rate;
    }

    return 38000 +
        (grossSalary - AppConstants.payeBracket2Max) * AppConstants.payeBracket3Rate;
  }

  static double calculatePensionEmployee(double gross) =>
      gross * AppConstants.pensionEmployeeRate;

  static double calculatePensionEmployer(double gross) =>
      gross * AppConstants.pensionEmployerRate;

  static double calculateMaternityEmployee(double gross) =>
      gross * AppConstants.maternityEmployeeRate;

  static double calculateMaternityEmployer(double gross) =>
      gross * AppConstants.maternityEmployerRate;

  static double calculateOccupationalHazard(double gross) =>
      gross * AppConstants.occupationalHazardRate;

  static PayslipModel calculatePayslip({
    required EmployeeModel employee,
    required String payrollMonth,
    required int workingDays,
    required int presentDays,
    double allowances = 0,
    double deductions = 0,
  }) {
    double effectiveGross = employee.grossSalary;

    // Pro-rate for daily/hourly or partial months
    if (employee.salaryType == AppConstants.salaryTypeFixedMonthly && workingDays > 0) {
      effectiveGross = (employee.grossSalary / workingDays) * presentDays;
    }

    effectiveGross += allowances;

    final adjustedGross = effectiveGross + deductions.abs();

    final pensionEmp = calculatePensionEmployee(adjustedGross);
    final pensionEmr = calculatePensionEmployer(adjustedGross);
    final maternityEmp = calculateMaternityEmployee(adjustedGross);
    final maternityEmr = calculateMaternityEmployer(adjustedGross);
    final occupational = calculateOccupationalHazard(adjustedGross);
    final paye = calculatePaye(adjustedGross);

    final totalEmployeeDeductions = pensionEmp + maternityEmp + paye + deductions.abs();
    final netSalary = effectiveGross - totalEmployeeDeductions;
    final totalEmployerCost =
        adjustedGross + pensionEmr + maternityEmr + occupational;

    return PayslipModel(
      employeeId: employee.id,
      companyId: employee.companyId,
      payrollMonth: payrollMonth,
      firstName: employee.firstName,
      lastName: employee.lastName,
      position: employee.position,
      department: employee.department,
      grossSalary: _round(adjustedGross),
      pensionEmployee: _round(pensionEmp),
      pensionEmployer: _round(pensionEmr),
      maternityEmployee: _round(maternityEmp),
      maternityEmployer: _round(maternityEmr),
      occupationalHazard: _round(occupational),
      paye: _round(paye),
      netSalary: _round(netSalary),
      totalEmployerCost: _round(totalEmployerCost),
      workingDays: workingDays,
      presentDays: presentDays,
      status: 'draft',
      bankName: employee.bankName,
      bankAccountNumber: employee.bankAccountNumber,
      rssbNumber: employee.rssbNumber,
      allowances: _round(allowances),
      deductions: _round(deductions),
    );
  }

  // Rounds to nearest whole number (RWF has no decimals)
  static double _round(double value) => value.roundToDouble();
}
