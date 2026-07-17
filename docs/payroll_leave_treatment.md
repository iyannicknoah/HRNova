# How Payroll Treats Employees On Leave

Source: `lib/features/payroll/services/payroll_engine.dart`

Leave is **not paid consistently** across salary types — it depends entirely on how each `salaryType` calculates base pay. There is no explicit "paid leave" vs "unpaid leave" setting; the outcome below is a side effect of the base salary formula.

---

## Fixed Monthly Employees — Leave is Paid

Base salary is always the flat `employee.salaryAmount`, regardless of attendance.

In the absent-deduction check (step 5 of the payroll chain), a day is **excluded from the absent count** if either:
- the date is in `approvedLeaveKeys` (an approved leave request exists), OR
- the attendance record has `isOnLeave == true`

```
hasApprovedLeave = date in approvedLeaveKeys
isMarkedOnLeave  = attendance record for date has isOnLeave == true

if NOT present AND NOT hasApprovedLeave AND NOT isMarkedOnLeave:
    → counts as absentDay → salary docked
else:
    → no deduction
```

Result: a leave day costs nothing. Employee is paid in full → **effectively paid leave**.

## Daily-Rate Employees — Leave is Unpaid

```
presentDays = count of working days where:
    checkInTime exists AND !isAbsent AND !isOnLeave

baseSalary = presentDays × dailyRate
```

A day marked `isOnLeave` is excluded from `presentDays`. Since pay is built entirely from days actually counted as present, a leave day simply **earns RWF 0** → **effectively unpaid leave**.

## Hourly-Rate Employees — Leave is Unpaid

```
For each attendance record:
    if isAbsent OR isOnLeave → skip (no hours counted)
    else → add hours worked
```

Same outcome as daily-rate: a leave day contributes zero hours → zero pay for that day.

## Overtime — Never Earned on Leave Days

The overtime loop also skips any record where `isAbsent || isOnLeave`, so no overtime accrues on a leave day (consistent, since the employee didn't work).

## Late Deduction — Never Triggered on Leave Days

Late deduction only sums minutes from records where `isLate == true`. A leave day has no check-in, so `isLate` stays false — no late penalty applies.

---

## Summary Table

| Salary Type    | Absent-deducted? | Base pay earned for leave day? | Net effect       |
|-----------------|:---:|:---:|-------------------|
| Fixed Monthly   | No  | Yes (flat salary unaffected) | Paid leave        |
| Daily Rate      | N/A (no absent deduction for this type) | No (day not counted as present) | Unpaid leave |
| Hourly Rate     | N/A (no absent deduction for this type) | No (no hours counted) | Unpaid leave |

## Known Gap

The system has no leave-type concept (paid vs. unpaid, annual vs. sick, etc.) that payroll consults. Whether leave is effectively paid or unpaid is purely a byproduct of the employee's `salaryType`, not a deliberate policy choice. Daily/hourly-rate employees lose income for every leave day taken, while fixed-monthly employees do not — regardless of company leave policy.

**Possible fix:** add a `paidLeave: bool` flag to leave requests / company settings, and have `daily_rate`/`hourly_rate` base-salary calculations credit a day's pay when the leave is flagged as paid.
