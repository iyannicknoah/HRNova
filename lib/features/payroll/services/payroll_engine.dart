import '../../attendance/models/attendance_model.dart';
import '../../employees/models/employee_model.dart';
import '../../settings/models/company_settings_model.dart';
import '../models/payroll_model.dart';

/// Pure-Dart payroll calculator — no UI, no Firebase.
/// All rounding to nearest whole RWF.
class PayrollEngine {
  PayrollEngine._();

  // ── Rwanda 2025 PAYE ─────────────────────────────────────────────────────────
  // Taxable income = adjustedGross (statutory — identical for all companies;
  // company-defined deductions do NOT reduce the PAYE base)
  static double calculatePaye(double gross) {
    if (gross <= 60000) return 0;
    if (gross <= 100000) return _r((gross - 60000) * 0.20);
    if (gross <= 200000) return _r(8000 + (gross - 100000) * 0.30);
    return _r(38000 + (gross - 200000) * 0.30);
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
  }) {
    final totalWorkingDays = workingDayKeys.length;

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
    }

    // ── Step 1b — Overtime ──────────────────────────────────────────────────
    double overtimeHours = 0;
    double overtimePay = 0;

    final workdayHours = _parseTimeH(settings.workEndTime) - _parseTimeH(settings.workStartTime);

    if (workdayHours > 0 && employee.salaryType != 'hourly_rate') {
      for (final rec in attendanceMap.values) {
        // Absent/leave-flagged records never earn overtime
        if (rec.isAbsent || rec.isOnLeave) continue;
        if (rec.checkInTime != null && rec.checkOutTime != null) {
          final hoursWorked = rec.checkOutTime!.difference(rec.checkInTime!).inMinutes / 60.0;
          if (hoursWorked > workdayHours) {
            overtimeHours += hoursWorked - workdayHours;
          }
        } else if (rec.workingHours != null && rec.workingHours! > workdayHours) {
          overtimeHours += rec.workingHours! - workdayHours;
        }
      }
      if (overtimeHours > 0) {
        final hourlyRate = employee.salaryType == 'daily_rate'
            ? employee.dailyRate / workdayHours
            : employee.salaryAmount / (workingDayKeys.length * workdayHours);
        overtimePay = _r(overtimeHours * hourlyRate * settings.overtimeMultiplier);
      }
    }

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
      if (absentDays > 0) {
        absentDeduction = _r((employee.salaryAmount / totalWorkingDays) * absentDays);
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
      final remaining = (loanMap['remainingAmount'] as num?)?.toDouble() ?? 0;
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
      workingDays: totalWorkingDays,
      presentDays: presentDays,
      status: 'draft',
    );
  }

  static double _r(double v) => v.roundToDouble();

  /// Parse a time string like "08:00" or "17:30" to decimal hours.
  static double _parseTimeH(String t) {
    final parts = t.split(':');
    if (parts.isEmpty) return 0;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0) / 60.0 : 0;
    return h + m;
  }

  // Rwanda public holidays — same list as AppConstants but used internally here
  static const _rwandaHolidays = {
    '01-01', '01-02', '02-01', '04-07', '05-01',
    '07-01', '07-04', '08-15', '12-25', '12-26',
  };
}
