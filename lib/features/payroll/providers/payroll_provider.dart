import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/models/attendance_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart' show leaveDateKey;
import '../../settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../models/payroll_model.dart';
import '../services/payroll_engine.dart';

// ── Streams ────────────────────────────────────────────────────────────────────

final payrollRunByMonthProvider =
    StreamProvider.autoDispose.family<PayrollRunModel?, String>((ref, month) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(null);
  return FirebaseService.payrollRef(companyId)
      .doc(month)
      .snapshots()
      .map((d) => d.exists ? PayrollRunModel.fromMap(d.data()!) : null);
});

final payslipsByMonthProvider =
    StreamProvider.autoDispose.family<List<PayslipModel>, String>((ref, month) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.payslipsRef(companyId, month)
      .orderBy('firstName')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => PayslipModel.fromMap(d.id, d.data())).toList());
});

final employeePayslipsProvider =
    StreamProvider.autoDispose.family<List<PayslipModel>, String>(
        (ref, employeeId) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.db
      .collectionGroup('payslips')
      .where('companyId', isEqualTo: companyId)
      .where('employeeId', isEqualTo: employeeId)
      .orderBy('payrollMonth', descending: true)
      .limit(24)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => PayslipModel.fromMap(d.id, d.data())).toList());
});

// ── State ─────────────────────────────────────────────────────────────────────

enum PayrollStep { idle, calculating, saving, done, error }

class PayrollState {
  const PayrollState({
    this.step = PayrollStep.idle,
    this.progress = 0,
    this.total = 0,
    this.currentName = '',
    this.payslips = const [],
    this.run,
    this.error,
  });

  final PayrollStep step;
  final int progress;
  final int total;
  final String currentName;
  final List<PayslipModel> payslips;
  final PayrollRunModel? run;
  final String? error;

  bool get isRunning =>
      step == PayrollStep.calculating || step == PayrollStep.saving;

  PayrollState copyWith({
    PayrollStep? step,
    int? progress,
    int? total,
    String? currentName,
    List<PayslipModel>? payslips,
    PayrollRunModel? run,
    String? error,
  }) =>
      PayrollState(
        step: step ?? this.step,
        progress: progress ?? this.progress,
        total: total ?? this.total,
        currentName: currentName ?? this.currentName,
        payslips: payslips ?? this.payslips,
        run: run ?? this.run,
        error: error,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class PayrollNotifier extends StateNotifier<PayrollState> {
  PayrollNotifier(this._ref) : super(const PayrollState());
  final Ref _ref;

  String? get _companyId => _ref.read(currentCompanyIdProvider);

  /// Calculate payslips for the month — stores result in state, does NOT save.
  Future<void> runPayroll(String month) async {
    final companyId = _companyId;
    if (companyId == null) return;

    state = const PayrollState(step: PayrollStep.calculating);

    try {
      final employees =
          _ref.read(employeesProvider).value?.where((e) => e.isActive).toList() ?? [];
      final settings = _ref.read(companySettingsProvider).value;
      if (settings == null) throw Exception('Company settings not loaded');

      final parts = month.split('-');
      final year = int.parse(parts[0]);
      final monthNum = int.parse(parts[1]);

      final workingDayKeys = PayrollEngine.workingDayKeysForMonth(
          year, monthNum, settings.workingDays);

      // Load all attendance for the month
      final attSnap = await FirebaseService.attendanceRef(companyId)
          .where('date', isGreaterThanOrEqualTo: '$month-01')
          .where('date', isLessThanOrEqualTo: '$month-31')
          .get();

      // Map: employeeId_dateKey → raw data
      final allAtt = <String, Map<String, dynamic>>{
        for (final d in attSnap.docs)
          '${d.data()['employeeId']}_${d.data()['date']}': d.data()
      };

      // Load approved leave requests
      final leaveSnap = await FirebaseService.leaveRef(companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      final approvedLeaveByEmployee = <String, Set<String>>{};
      for (final d in leaveSnap.docs) {
        final data = d.data();
        final empId = data['employeeId'] as String? ?? '';
        final startStr = data['startDate'] as String? ?? '';
        final endStr = data['endDate'] as String? ?? '';
        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start == null || end == null || empId.isEmpty) continue;

        approvedLeaveByEmployee.putIfAbsent(empId, () => {});
        var cur = start;
        while (!cur.isAfter(end)) {
          final key = leaveDateKey(cur);
          if (key.startsWith(month)) {
            approvedLeaveByEmployee[empId]!.add(key);
          }
          cur = cur.add(const Duration(days: 1));
        }
      }

      state = state.copyWith(total: employees.length);
      final payslips = <PayslipModel>[];

      for (var i = 0; i < employees.length; i++) {
        final emp = employees[i];
        state = state.copyWith(progress: i + 1, currentName: emp.fullName);

        final attModelMap = <String, AttendanceModel>{};
        for (final key in workingDayKeys) {
          final combined = '${emp.id}_$key';
          if (allAtt.containsKey(combined)) {
            attModelMap[key] = AttendanceModel.fromMap(combined, allAtt[combined]!);
          }
        }

        final payslip = PayrollEngine.calculatePayslip(
          employee: emp,
          payrollMonth: month,
          attendanceMap: attModelMap,
          approvedLeaveKeys: approvedLeaveByEmployee[emp.id] ?? {},
          workingDayKeys: workingDayKeys,
          settings: settings,
        );
        payslips.add(payslip);
        await Future.delayed(Duration.zero); // yield to UI
      }

      state = state.copyWith(step: PayrollStep.done, payslips: payslips);
    } catch (e) {
      state = state.copyWith(step: PayrollStep.error, error: e.toString());
    }
  }

  /// Persist payslips + run header to Firestore.
  Future<void> savePayroll(String month) async {
    final companyId = _companyId;
    if (companyId == null || state.payslips.isEmpty) return;

    state = state.copyWith(step: PayrollStep.saving);
    try {
      final batch = FirebaseService.db.batch();
      final psRef = FirebaseService.payslipsRef(companyId, month);

      double totalEarnings = 0, totalGross = 0, totalNet = 0,
          totalPaye = 0, totalRssb = 0, totalEmployerCost = 0;

      for (final ps in state.payslips) {
        batch.set(psRef.doc(ps.employeeId), {
          ...ps.toMap(),
          'createdAt': DateTime.now().toIso8601String(),
        });
        totalEarnings += ps.totalEarnings;
        totalGross += ps.adjustedGross;
        totalNet += ps.netSalary;
        totalPaye += ps.paye;
        totalRssb += ps.totalEmployeeRssb + ps.pensionEmployer + ps.maternityEmployer;
        totalEmployerCost += ps.totalEmployerCost;
      }

      final run = PayrollRunModel(
        companyId: companyId,
        payrollMonth: month,
        status: 'draft',
        totalEarnings: totalEarnings,
        totalGross: totalGross,
        totalNet: totalNet,
        totalPaye: totalPaye,
        totalRssb: totalRssb,
        totalEmployerCost: totalEmployerCost,
        employeeCount: state.payslips.length,
        createdAt: DateTime.now(),
      );
      batch.set(
          FirebaseService.payrollRef(companyId).doc(month), run.toMap());

      await batch.commit();
      state = state.copyWith(step: PayrollStep.done, run: run);
    } catch (e) {
      state = state.copyWith(step: PayrollStep.error, error: e.toString());
    }
  }

  /// Delete a saved draft run (all payslips + run header) so payroll can be re-run.
  Future<void> deleteDraft(String month) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final snap = await FirebaseService.payslipsRef(companyId, month).get();
    final batch = FirebaseService.db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(FirebaseService.payrollRef(companyId).doc(month));
    await batch.commit();

    state = const PayrollState();
  }

  /// Apply per-employee adjustment and re-save the payslip.
  Future<void> adjustPayslip(
    String month,
    String employeeId, {
    double? bonuses,
    String? bonusDescription,
    double? extraDeductions,
    String? extraDeductionsDescription,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;
    try {
      final snap = await FirebaseService.payslipsRef(companyId, month)
          .doc(employeeId)
          .get();
      if (!snap.exists) return;

      final updated = PayslipModel.fromMap(snap.id, snap.data()!).copyWith(
        bonuses: bonuses,
        bonusDescription: bonusDescription,
        extraDeductions: extraDeductions,
        extraDeductionsDescription: extraDeductionsDescription,
      );
      await snap.reference.set(updated.toMap());
      await _recalcRunTotals(month, companyId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Lock the payroll and decrease loan balances for each employee.
  Future<void> approvePayroll(String month) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final displayName =
        _ref.read(userClaimsProvider).value?['displayName'] as String? ??
            'HR Admin';
    final now = DateTime.now().toIso8601String();

    final payslipsSnap =
        await FirebaseService.payslipsRef(companyId, month).get();

    final batch = FirebaseService.db.batch();

    for (final d in payslipsSnap.docs) {
      // 1 — Approve payslip
      batch.update(d.reference,
          {'status': 'approved', 'approvedBy': displayName, 'approvedAt': now});

      // 2 — Decrease loan balances if this employee had loan deductions
      final ps = PayslipModel.fromMap(d.id, d.data());
      if (ps.loanDeductions > 0) {
        final empRef = FirebaseService.db
            .collection('companies')
            .doc(companyId)
            .collection('employees')
            .doc(ps.employeeId);

        final empSnap = await empRef.get();
        if (empSnap.exists) {
          final rawLoans =
              List<Map<String, dynamic>>.from(
                  (empSnap.data()!['loans'] as List? ?? [])
                      .map((l) => Map<String, dynamic>.from(l as Map)));

          double remaining = ps.loanDeductions;
          final updatedLoans = rawLoans.map((loan) {
            if (remaining <= 0) return loan;
            final status = loan['status'] as String? ?? 'active';
            final rem = (loan['remainingAmount'] as num?)?.toDouble() ?? 0;
            final monthly = (loan['monthlyDeduction'] as num?)?.toDouble() ?? 0;
            if (status != 'active' || rem <= 0 || monthly <= 0) return loan;

            final deducted = monthly.clamp(0, rem);
            remaining -= deducted;
            final newRem = rem - deducted;
            return {
              ...loan,
              'remainingAmount': newRem,
              if (newRem <= 0) 'status': 'paid',
            };
          }).toList();

          batch.update(empRef, {'loans': updatedLoans});
        }
      }
    }

    batch.update(FirebaseService.payrollRef(companyId).doc(month),
        {'status': 'approved', 'approvedBy': displayName, 'approvedAt': now});

    await batch.commit();
  }

  /// Mark a payslip as email-sent.
  Future<void> markEmailSent(String month, String employeeId) async {
    final companyId = _companyId;
    if (companyId == null) return;
    await FirebaseService.payslipsRef(companyId, month)
        .doc(employeeId)
        .update({'emailSent': true});
  }

  void reset() => state = const PayrollState();

  Future<void> _recalcRunTotals(String month, String companyId) async {
    final snap = await FirebaseService.payslipsRef(companyId, month).get();
    double te = 0, tg = 0, tn = 0, tp = 0, tr = 0, tc = 0;
    for (final d in snap.docs) {
      final ps = PayslipModel.fromMap(d.id, d.data());
      te += ps.totalEarnings;
      tg += ps.adjustedGross;
      tn += ps.netSalary;
      tp += ps.paye;
      tr += ps.totalEmployeeRssb + ps.pensionEmployer + ps.maternityEmployer;
      tc += ps.totalEmployerCost;
    }
    await FirebaseService.payrollRef(companyId).doc(month).update({
      'totalEarnings': te,
      'totalGross': tg,
      'totalNet': tn,
      'totalPaye': tp,
      'totalRssb': tr,
      'totalEmployerCost': tc,
      'employeeCount': snap.docs.length,
    });
  }
}

final payrollNotifierProvider =
    StateNotifierProvider<PayrollNotifier, PayrollState>(
  (ref) => PayrollNotifier(ref),
);
