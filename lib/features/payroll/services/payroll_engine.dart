import '../../attendance/models/attendance_model.dart';
import '../../employees/models/employee_model.dart';
import '../../settings/models/company_settings_model.dart';
import '../models/payroll_model.dart';

/// Pure-Dart payroll calculator — no UI, no Firebase.
/// All rounding to nearest whole RWF.
class PayrollEngine {
  PayrollEngine._();

  // ── Rwanda PAYE (Law No. 027/2022, 4-bracket rates effective Nov 2023) ─────
  // Taxable income = adjustedGross (statutory — identical for all companies;
  // company-defined deductions do NOT reduce the PAYE base)
  static double calculatePaye(double gross) {
    if (gross <= 60000) return 0;
    if (gross <= 100000) return _r((gross - 60000) * 0.10);
    if (gross <= 200000) return _r(4000 + (gross - 100000) * 0.20);
    return _r(24000 + (gross - 200000) * 0.30);
  }

  /// Applies the company's active deduction rules for [side] on
  /// [adjustedGross], snapshotting title + percent + computed amount.
  static List<PayslipDeductionLine> applyDeductions(
      List<DeductionRule> rules, String side, double adjustedGross) {
    return rules
        .where((r) => r.active && r.side == side)
        .map((r) => PayslipDeductionLine(
              title: r.title,
              percent: r.percent,
              amount: _r(adjustedGross * r.percent / 100),
            ))
        .toList();
  }

  // ── Working days in a month ───────────────────────────────────────────────
  static List<String> workingDayKeysForMonth(
      int year, int month, List<String> workingDays) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0); // last day of month
    final keys = <String>[];
    var cur = first;
    while (!cur.isAfter(last)) {
      final dayName = _dayName(cur.weekday);
      final mmdd =
          '${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
      if (workingDays.contains(dayName) && !_rwandaHolidays.contains(mmdd)) {
        keys.add(
            '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}');
      }
      cur = cur.add(const Duration(days: 1));
    }
    return keys;
  }

  static String _dayName(int weekday) => switch (weekday) {
        1 => 'monday',
        2 => 'tuesday',
        3 => 'wednesday',
        4 => 'thursday',
        5 => 'friday',
        6 => 'saturday',
        7 => 'sunday',
        _ => '',
      };

  /// Dates within the month that would be a working day (matches the
  /// company's configured days-of-week) but are excluded from
  /// [workingDayKeysForMonth] because they're a Rwanda public holiday.
  /// Used to credit fixed-monthly employees for holidays as paid days —
  /// daily/hourly pay is untouched by this list.
  static List<String> holidayWorkingDayKeysForMonth(
      int year, int month, List<String> workingDays) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final keys = <String>[];
    var cur = first;
    while (!cur.isAfter(last)) {
      final dayName = _dayName(cur.weekday);
      final mmdd =
          '${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
      if (workingDays.contains(dayName) && _rwandaHolidays.contains(mmdd)) {
        keys.add(
            '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}');
      }
      cur = cur.add(const Duration(days: 1));
    }
    return keys;
  }

  // ── Full payslip calculation — 10 steps ──────────────────────────────────
  /// [attendanceMap]: date key → AttendanceModel for the month.
  /// [approvedLeaveKeys]: date keys where employee had an approved leave request.
  /// [workingDayKeys]: all working day keys for the month.
  static PayslipModel calculatePayslip({
    required EmployeeModel employee,
    required String payrollMonth, // YYYY-MM
    required Map<String, AttendanceModel> attendanceMap,
    required Set<String> approvedLeaveKeys,
    required List<String> workingDayKeys,
    required CompanySettingsModel settings,
    double bonuses = 0,
    String? bonusDescription,
    double extraDeductions = 0,
    String? extraDeductionsDescription,
    /// Dates that would be a working day but fall on a public holiday
    /// (see [holidayWorkingDayKeysForMonth]). Fixed-monthly employees are
    /// credited for these as paid present days; daily/hourly pay ignores
    /// this list entirely, unchanged from before.
    List<String> holidayKeys = const [],
  }) {
    final totalWorkingDays = workingDayKeys.length;
    // Fixed-monthly only: holidays count as paid days, so they widen the
    // "how many days is a month's salary spread over" denominator — without
    // this, excluding holidays from the denominator makes every real
    // absence cost more than it should.
    final totalPayableDaysForFixedMonthly = totalWorkingDays + holidayKeys.length;

    // ── Step 1 — Base salary ────────────────────────────────────────────────
    double baseSalary;
    int presentDays = 0;
    double totalHoursWorked = 0;

    switch (employee.salaryType) {
      case 'daily_rate':
        // Count days where employee was present (checked in, not absent, not on leave)
        for (final key in workingDayKeys) {
          final rec = attendanceMap[key];
          if (rec != null && rec.checkInTime != null && !rec.isAbsent && !rec.isOnLeave) {
            presentDays++;
          }
        }
        baseSalary = _r(presentDays * employee.dailyRate);
        break;
      case 'hourly_rate':
        for (final rec in attendanceMap.values) {
          // Consistent with daily_rate: a record flagged absent (or on
          // leave) never earns hours, even if check-in/out times exist.
          if (rec.isAbsent || rec.isOnLeave) continue;
          if (rec.checkInTime != null && rec.checkOutTime != null) {
            totalHoursWorked +=
                rec.checkOutTime!.difference(rec.checkInTime!).inMinutes / 60.0;
            presentDays++;
          } else if (rec.workingHours != null) {
            totalHoursWorked += rec.workingHours!;
            presentDays++;
          }
        }
        baseSalary = _r(totalHoursWorked * employee.hourlyRate);
        break;
      default: // fixed_monthly
        baseSalary = _r(employee.salaryAmount);
        // Count present days (for display) — absent/leave-flagged records
        // don't count even when a check-in time was recorded.
        for (final key in workingDayKeys) {
          final rec = attendanceMap[key];
          if (rec != null && rec.checkInTime != null && !rec.isAbsent && !rec.isOnLeave) {
            presentDays++;
          }
        }
        // Holidays are paid days regardless of attendance — credit them as
        // present so the count (and the deduction math below) reflects that
        // the employee is entitled to pay for those days.
        presentDays += holidayKeys.length;
    }

    // Overtime is no longer auto-calculated from attendance check-out times —
    // these stay at 0 (the payslip PDF/UI hide the row when overtimePay is 0).
    const double overtimeHours = 0;
    const double overtimePay = 0;

    // ── Step 2 — Gross ──────────────────────────────────────────────────────
    final transportAllowance = _r(employee.transportAllowance);
    final housingAllowance = _r(employee.housingAllowance);
    final grossBeforeAdjustments = baseSalary + transportAllowance + housingAllowance + bonuses + overtimePay;

    // ── Step 3 — Absent deduction (fixed_monthly only) ─────────────────────
    int absentDays = 0;
    double absentDeduction = 0;

    if (employee.salaryType == 'fixed_monthly' && totalWorkingDays > 0) {
      for (final key in workingDayKeys) {
        final rec = attendanceMap[key];
        final hasApprovedLeave = approvedLeaveKeys.contains(key);
        final isMarkedOnLeave = rec != null && rec.isOnLeave;
        // A record flagged absent counts as an absent day even when a
        // check-in time was recorded (e.g. after-hours check-in attempt).
        final hasAttendance =
            rec != null && rec.checkInTime != null && !rec.isAbsent;
        if (!hasAttendance && !hasApprovedLeave && !isMarkedOnLeave) {
          absentDays++;
        }
      }
      // absentDays is always counted (shown on payslips); money is only
      // docked when the company opted into absent-day deductions. The
      // per-day rate is spread over working days PLUS holidays (holidays
      // are paid days too), so excluding holidays never inflates the cost
      // of a real absence.
      if (absentDays > 0 && settings.deductAbsentDays) {
        absentDeduction = _r(
            (employee.salaryAmount / totalPayableDaysForFixedMonthly) * absentDays);
      }
    }

    // ── Step 4 — Late deduction ─────────────────────────────────────────────
    int totalLateMinutes = 0;
    for (final rec in attendanceMap.values) {
      if (rec.isLate) totalLateMinutes += rec.lateMinutes;
    }
    final lateDeduction = totalLateMinutes > 0
        ? _r((totalLateMinutes / 60.0) * settings.lateDeductionPerHourRwf)
        : 0.0;

    // ── Step 5 — Adjusted gross ─────────────────────────────────────────────
    final adjustedGross = _r(grossBeforeAdjustments - absentDeduction - lateDeduction)
        .clamp(0.0, double.infinity);

    // ── Step 6 — Company-defined employee deductions ────────────────────────
    final employeeDeductions = applyDeductions(
        settings.deductions, DeductionRule.sideEmployee, adjustedGross);
    final totalEmployeeDeductionLines =
        employeeDeductions.fold(0.0, (s, l) => s + l.amount);

    // ── Step 7 — PAYE ───────────────────────────────────────────────────────
    final paye = calculatePaye(adjustedGross);

    // ── Step 8 — Loan deductions ────────────────────────────────────────────
    double loanDeductions = 0;
    for (final loan in employee.loans) {
      final loanMap = loan as Map<String, dynamic>? ?? {};
      final status = loanMap['status'] as String? ?? 'active';
      final remaining = _loanRemaining(loanMap);
      final monthly = (loanMap['monthlyDeduction'] as num?)?.toDouble() ?? 0;
      if (status == 'active' && remaining > 0 && monthly > 0) {
        loanDeductions += monthly.clamp(0, remaining);
      }
    }
    loanDeductions = _r(loanDeductions);

    // ── Step 9 — Net salary ─────────────────────────────────────────────────
    final totalDeductions =
        _r(totalEmployeeDeductionLines + paye + loanDeductions + extraDeductions);
    final netSalary = _r(adjustedGross - totalDeductions).clamp(0.0, double.infinity);

    // ── Step 10 — Employer costs (company-defined employer contributions) ──
    final employerContributions = applyDeductions(
        settings.deductions, DeductionRule.sideEmployer, adjustedGross);
    final totalEmployerCost = _r(adjustedGross +
        employerContributions.fold(0.0, (s, l) => s + l.amount));

    return PayslipModel(
      id: employee.id,
      employeeId: employee.id,
      companyId: employee.companyId,
      payrollMonth: payrollMonth,
      firstName: employee.firstName,
      lastName: employee.lastName,
      position: employee.jobTitle,
      department: employee.department,
      nationalId: employee.nationalId,
      rssbNumber: employee.rssbNumber,
      bankAccountNumber: employee.bankAccount,
      bankCode: employee.bankCode,
      branchId: employee.branchId,
      baseSalary: baseSalary,
      transportAllowance: transportAllowance,
      housingAllowance: housingAllowance,
      bonuses: bonuses,
      bonusDescription: bonusDescription,
      totalEarnings: _r(grossBeforeAdjustments),
      overtimeHours: overtimeHours,
      overtimePay: overtimePay,
      absentDays: absentDays,
      absentDeduction: absentDeduction,
      totalLateMinutes: totalLateMinutes,
      lateDeduction: lateDeduction,
      adjustedGross: adjustedGross,
      employeeDeductions: employeeDeductions,
      employerContributions: employerContributions,
      paye: paye,
      loanDeductions: loanDeductions,
      extraDeductions: extraDeductions,
      extraDeductionsDescription: extraDeductionsDescription,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
      totalEmployerCost: totalEmployerCost,
      // Fixed-monthly shows holidays included in the day count (matches the
      // presentDays credit above and the deduction denominator); daily/
      // hourly keep the plain working-day count, unchanged from before.
      workingDays: employee.salaryType == 'fixed_monthly'
          ? totalPayableDaysForFixedMonthly
          : totalWorkingDays,
      presentDays: presentDays,
      status: 'draft',
    );
  }

  static double _r(double v) => v.roundToDouble();

  /// Remaining balance of a loan. Falls back to totalAmount - amountPaid for
  /// loans recorded before remainingAmount was persisted at creation.
  static double _loanRemaining(Map<String, dynamic> loanMap) {
    final stored = (loanMap['remainingAmount'] as num?)?.toDouble();
    if (stored != null) return stored;
    final total = (loanMap['totalAmount'] as num?)?.toDouble() ?? 0;
    final paid = (loanMap['amountPaid'] as num?)?.toDouble() ?? 0;
    return (total - paid).clamp(0.0, total);
  }


  // Rwanda public holidays — same list as AppConstants but used internally here
  static const _rwandaHolidays = {
    '01-01', '01-02', '02-01', '04-07', '05-01',
    '07-01', '07-04', '08-15', '12-25', '12-26',
  };
}
