# HRNova Payroll Formulas

Source: `lib/features/payroll/services/payroll_engine.dart`
All amounts rounded to nearest whole RWF at each step.

---

## 1. Working Days (denominator for daily-rate math)

```
totalWorkingDays = count of days in the month where:
    weekday is in company's configured working days
    AND day is not a Rwanda public holiday
```

## 2. Base Salary — depends on `salaryType`

**fixed_monthly**
```
baseSalary = employee.salaryAmount
```

**daily_rate**
```
presentDays = count of working days where: checkInTime exists AND !isAbsent AND !isOnLeave
baseSalary  = presentDays × employee.dailyRate
```

**hourly_rate**
```
For each attendance record where !isAbsent AND !isOnLeave:
    hoursWorked = (checkOutTime - checkInTime) in hours   [or record.workingHours if set]
totalHoursWorked = sum of all hoursWorked
baseSalary = totalHoursWorked × employee.hourlyRate
```

## 3. Overtime (skipped for hourly_rate employees)

```
workdayHours = workEndTime - workStartTime   (from company settings)

For each present, non-leave record where hoursWorked > workdayHours:
    overtimeHours += (hoursWorked - workdayHours)

hourlyRate = daily_rate employee:  dailyRate / workdayHours
             fixed_monthly:        salaryAmount / (totalWorkingDays × workdayHours)

overtimePay = overtimeHours × hourlyRate × settings.overtimeMultiplier
```

## 4. Total Earnings (gross before any deduction)

```
totalEarnings = baseSalary + transportAllowance + housingAllowance + bonuses + overtimePay
```

## 5. Absent Deduction (fixed_monthly employees only)

```
A day counts as absent if:
    (no attendance record OR no checkInTime OR isAbsent == true)
    AND no approved leave for that day
    AND not marked isOnLeave

absentDeduction = (salaryAmount / totalWorkingDays) × absentDays
```
`daily_rate` / `hourly_rate` employees have no separate absent deduction — absent days are simply never paid (they don't add to `presentDays`/`totalHoursWorked` in step 2).

## 6. Late Deduction

```
gracedStart = workStartTime + gracePeriodMinutes
isLate      = checkInTime > gracedStart
lateMinutes = isLate ? (checkInTime - gracedStart) in minutes : 0   [grace period excluded]

totalLateMinutes = sum of lateMinutes across the month
lateDeduction = (totalLateMinutes / 60) × settings.lateDeductionPerHourRwf   (default 500 RWF/hr)
```
Note: if a check-in happens *after* the work-end cutoff, the day is marked `isAbsent = true` instead of late (see step 5), and no late deduction applies to it.

## 7. Adjusted Gross

```
adjustedGross = max(0, totalEarnings - absentDeduction - lateDeduction)
```

## 8. Employee-Side Deductions (RSSB etc., % of Adjusted Gross)

```
For each active deduction rule where side == 'employee':
    amount = adjustedGross × rule.percent / 100

Default Rwanda RSSB scheme:
    RSSB Pension    6%
    RSSB Maternity  0.3%

totalEmployeeDeductionLines = sum of all employee-side rule amounts
```
Company can edit/add/remove rules in Settings → Deductions.

## 9. PAYE (Rwanda Law No. 027/2022, 4-bracket rates effective Nov 2023, on Adjusted Gross)

```
gross ≤ 60,000            → PAYE = 0
60,000 < gross ≤ 100,000  → PAYE = (gross - 60,000) × 10%
100,000 < gross ≤ 200,000 → PAYE = 4,000 + (gross - 100,000) × 20%
gross > 200,000           → PAYE = 24,000 + (gross - 200,000) × 30%
```
Company-defined deductions do NOT reduce the PAYE base — PAYE is always computed on the full `adjustedGross`.

## 10. Loan Deductions

```
For each active loan with remainingAmount > 0 and monthlyDeduction > 0:
    loanDeductions += min(monthlyDeduction, remainingAmount)
```

## 11. Net Salary

```
totalDeductions = totalEmployeeDeductionLines + PAYE + loanDeductions + extraDeductions
netSalary = max(0, adjustedGross - totalDeductions)
```

## 12. Employer Cost (not deducted from employee — company's total cost)

```
For each active deduction rule where side == 'employer':
    amount = adjustedGross × rule.percent / 100

Default Rwanda RSSB employer scheme:
    RSSB Pension              6%
    RSSB Maternity            0.3%
    RSSB Occupational Hazard  2%

totalEmployerCost = adjustedGross + sum of all employer-side rule amounts
```

---

## Full Chain, Top to Bottom

```
Total Earnings
   − Absent Deduction (fixed_monthly only)
   − Late Deduction
   = Adjusted Gross
   − PAYE (bracket calc on Adjusted Gross)
   − Employee Deductions (RSSB Pension 6% + Maternity 0.3%, on Adjusted Gross)
   − Loan Deductions (fixed installment)
   − Extra Deductions (fixed, manual)
   = Net Salary

Adjusted Gross
   + Employer Deductions (RSSB Pension 6% + Maternity 0.3% + Occ. Hazard 2%, on Adjusted Gross)
   = Total Employer Cost
```
