import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/working_days_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/leave_request_model.dart';

// ── Branch filter helper ──────────────────────────────────────────────────────
// Returns a Firestore query filtered by branchId when the current user is a
// branch_hr_admin. Docs without a branchId field (created before multi-branch
// was enabled) will not match, giving branch HRs a clean slate.
Query<Map<String, dynamic>> _branchLeaveQuery(
  Ref ref,
  Query<Map<String, dynamic>> base,
) {
  final role     = ref.watch(currentUserRoleProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  if ((role == AppConstants.roleBranchHrAdmin || role == AppConstants.roleManager) && branchId != null) {
    return base.where('branchId', isEqualTo: branchId);
  }
  return base;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String leaveDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Stream: pending requests ──────────────────────────────────────────────────

final pendingLeaveRequestsProvider =
    StreamProvider.autoDispose<List<LeaveRequestModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final base = _branchLeaveQuery(
    ref,
    FirebaseService.leaveRef(companyId).where('status', isEqualTo: 'pending'),
  );
  return base
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LeaveRequestModel.fromMap(d.id, d.data())).toList());
});

// ── Stream: all requests ──────────────────────────────────────────────────────

final allLeaveRequestsProvider =
    StreamProvider.autoDispose<List<LeaveRequestModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final base = _branchLeaveQuery(ref, FirebaseService.leaveRef(companyId));
  return base
      .orderBy('requestedAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LeaveRequestModel.fromMap(d.id, d.data())).toList());
});

// ── Stream: expired (pending requests whose endDate is in the past) ──────────

final expiredLeaveRequestsProvider =
    StreamProvider.autoDispose<List<LeaveRequestModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final base = _branchLeaveQuery(
    ref,
    FirebaseService.leaveRef(companyId).where('status', isEqualTo: 'pending'),
  );
  return base.snapshots().map((s) {
    final cutoff = DateTime.now();
    final today = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final list = s.docs
        .map((d) => LeaveRequestModel.fromMap(d.id, d.data()))
        .where((r) => r.endDate.isBefore(today))
        .toList()
      ..sort((a, b) => b.endDate.compareTo(a.endDate));
    return list;
  });
});

// ── Stream: one employee's requests ──────────────────────────────────────────

final employeeLeaveRequestsProvider =
    StreamProvider.autoDispose.family<List<LeaveRequestModel>, String>(
        (ref, employeeId) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.leaveRef(companyId)
      .where('employeeId', isEqualTo: employeeId)
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LeaveRequestModel.fromMap(d.id, d.data())).toList());
});

// ── Stream: leaves calendar by date → Set<employeeId> ────────────────────────

final leavesCalendarByDateProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, dateStr) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(<String>{});
  return FirebaseService.leavesCalendarRef(companyId)
      .where('date', isEqualTo: dateStr)
      .snapshots()
      .map((s) => s.docs
          .map((d) => d.data()['employeeId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet());
});

// ── Stream: leaves calendar by month ─────────────────────────────────────────

typedef _LCMonthParam = ({int year, int month});

final leavesCalendarByMonthProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, _LCMonthParam>(
        (ref, p) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final start =
      '${p.year}-${p.month.toString().padLeft(2, '0')}-01';
  final endMonth = p.month == 12 ? 1 : p.month + 1;
  final endYear = p.month == 12 ? p.year + 1 : p.year;
  final end = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';
  return FirebaseService.leavesCalendarRef(companyId)
      .where('date', isGreaterThanOrEqualTo: start)
      .where('date', isLessThan: end)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

// ── Stream: employee IDs on approved leave for any given date string ──────────

final approvedLeavesByDateProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, dateStr) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value({});
  final base = _branchLeaveQuery(
    ref,
    FirebaseService.leaveRef(companyId)
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: '${dateStr}T23:59:59.999'),
  );
  return base.snapshots().map((s) => s.docs
      .where((d) => (d.data()['endDate'] as String? ?? '').compareTo(dateStr) >= 0)
      .map((d) => d.data()['employeeId'] as String? ?? '')
      .where((id) => id.isNotEmpty)
      .toSet());
});

// ── Active leave roster: approved leaves active today ─────────────────────────

final activeLeaveRosterProvider =
    StreamProvider.autoDispose<List<LeaveRequestModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final base = _branchLeaveQuery(
    ref,
    FirebaseService.leaveRef(companyId)
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: '${todayStr}T23:59:59.999'),
  );
  return base.snapshots().map((s) => s.docs
      .where((d) => (d.data()['endDate'] as String? ?? '').compareTo(todayStr) >= 0)
      .map((d) => LeaveRequestModel.fromMap(d.id, d.data()))
      .toList()
    ..sort((a, b) => a.endDate.compareTo(b.endDate)));
});

// ── Stream: count of approved leaves active today ─────────────────────────────

final approvedLeavesTodayProvider = StreamProvider.autoDispose<int>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(0);
  final now      = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final base = _branchLeaveQuery(
    ref,
    FirebaseService.leaveRef(companyId)
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: '${todayStr}T23:59:59.999'),
  );
  return base.snapshots().map((s) => s.docs.where((d) {
        final end = (d.data()['endDate'] as String? ?? '');
        return end.compareTo(todayStr) >= 0;
      }).length);
});

// ── Notification streams ──────────────────────────────────────────────────────

final unreadNotificationsCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value(0);
  return FirebaseService.notificationsRef(companyId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
});

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.notificationsRef(companyId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList());
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class LeaveNotifier extends StateNotifier<AsyncValue<void>> {
  LeaveNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  String? get _companyId => _ref.read(currentCompanyIdProvider);
  String? get _uid => FirebaseService.currentUserId;

  // ── Submit leave request (employee, mobile) ─────────────────────────────────
  Future<void> submitLeaveRequest({
    required String employeeId,
    required String employeeName,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? branchId,
    String source = 'mobile_app',
    String? attachmentUrl,
    bool isExtension = false,
    String? originalRequestId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final settings = _ref.read(companySettingsProvider).value;
      final workingDays = settings?.workingDays ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

      final totalDays =
          WorkingDaysService.calculate(startDate, endDate, workingDays);

      final docRef = FirebaseService.leaveRef(companyId).doc();
      await docRef.set({
        'companyId': companyId,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'leaveType': leaveType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalDays': totalDays,
        'reason': reason,
        'status': 'pending',
        'source': source,
        if (branchId != null) 'branchId': branchId,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (isExtension) 'isExtension': true,
        if (originalRequestId != null) 'originalRequestId': originalRequestId,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseService.notificationsRef(companyId).add({
        'type': 'leave_request',
        'title': 'New Leave Request',
        'body':
            '$employeeName requested ${_typeLabel(leaveType)} leave ($totalDays days)',
        'employeeId': employeeId,
        'leaveRequestId': docRef.id,
        'targetRole': 'hr_admin',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Approve leave (HR) ──────────────────────────────────────────────────────
  Future<void> approveLeaveRequest(LeaveRequestModel req) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final settings = _ref.read(companySettingsProvider).value;
      final workingDays = settings?.workingDays ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

      final db = FirebaseService.db;
      final batch = db.batch();

      // Recalculate days at approval time — stored value may be 0 (e.g. weekend request)
      final recalcDays = WorkingDaysService.calculate(
        req.startDate, req.endDate, workingDays,
      );
      final effectiveDays = recalcDays > 0 ? recalcDays : req.totalDays > 0 ? req.totalDays : 1;

      // 1. Update request status + correct totalDays if it was wrong
      final approverRole = _ref.read(currentUserRoleProvider) ?? 'hr_admin';
      batch.update(FirebaseService.leaveRef(companyId).doc(req.id), {
        'status': 'approved',
        'approvedBy': _uid,
        'approvedByRole': approverRole,
        'approvedAt': FieldValue.serverTimestamp(),
        'totalDays': effectiveDays,
      });

      // 2. Deduct balance (annual, sick, maternity, paternity only)
      final balanceKey = _balanceKey(req.leaveType);
      if (balanceKey != null) {
        batch.update(
            FirebaseService.employeesRef(companyId).doc(req.employeeId), {
          'leaveBalances.$balanceKey': FieldValue.increment(-effectiveDays),
        });
      }

      // 3. Write leaves_calendar entries for each working day
      var current =
          DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
      final last =
          DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
      while (!current.isAfter(last)) {
        final dayName = _dayName(current.weekday);
        final mmdd =
            '${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        if (workingDays.contains(dayName) &&
            !AppConstants.rwandaHolidays.contains(mmdd)) {
          final dateStr = leaveDateKey(current);
          final calDocId = '${dateStr}_${req.employeeId}';
          batch.set(
              FirebaseService.leavesCalendarRef(companyId).doc(calDocId), {
            'employeeId': req.employeeId,
            'employeeName': req.employeeName,
            'date': dateStr,
            'leaveType': req.leaveType,
            'leaveRequestId': req.id,
          });
        }
        current = current.add(const Duration(days: 1));
      }

      // 4. Notify employee
      batch.set(FirebaseService.notificationsRef(companyId).doc(), {
        'type': 'leave_approved',
        'title': 'Leave Approved',
        'body':
            'Your ${_typeLabel(req.leaveType)} leave ($effectiveDays days) has been approved.',
        'employeeId': req.employeeId,
        'leaveRequestId': req.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Reject leave (HR) ───────────────────────────────────────────────────────
  Future<void> rejectLeaveRequest(LeaveRequestModel req, String reason) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final db = FirebaseService.db;
      final batch = db.batch();

      final approverRole = _ref.read(currentUserRoleProvider) ?? 'hr_admin';
      batch.update(FirebaseService.leaveRef(companyId).doc(req.id), {
        'status': 'rejected',
        'rejectedReason': reason,
        'rejectedBy': _uid,
        'rejectedByRole': approverRole,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseService.notificationsRef(companyId).doc(), {
        'type': 'leave_rejected',
        'title': 'Leave Request Declined',
        'body':
            'Your ${_typeLabel(req.leaveType)} leave request was declined. Reason: $reason',
        'employeeId': req.employeeId,
        'leaveRequestId': req.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Transaction-guarded approve (manager OR HR — whoever acts first wins) ────
  Future<String?> approveLeaveGuarded(LeaveRequestModel req) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final settings = _ref.read(companySettingsProvider).value;
      final workingDays = settings?.workingDays ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
      final approverRole = _ref.read(currentUserRoleProvider) ?? 'manager';

      final db = FirebaseService.db;
      final reqRef = FirebaseService.leaveRef(companyId).doc(req.id);
      String? alreadyHandledBy;

      await db.runTransaction((tx) async {
        final snap = await tx.get(reqRef);
        final status = snap.data()?['status'] as String? ?? '';
        if (status != 'pending') {
          alreadyHandledBy = snap.data()?['approvedByRole'] ?? snap.data()?['rejectedByRole'] ?? 'someone';
          return;
        }
        final recalcDays = WorkingDaysService.calculate(req.startDate, req.endDate, workingDays);
        final effectiveDays = recalcDays > 0 ? recalcDays : req.totalDays > 0 ? req.totalDays : 1;

        tx.update(reqRef, {
          'status': 'approved',
          'approvedBy': _uid,
          'approvedByRole': approverRole,
          'approvedAt': FieldValue.serverTimestamp(),
          'totalDays': effectiveDays,
        });
        final balanceKey = _balanceKey(req.leaveType);
        if (balanceKey != null) {
          tx.update(FirebaseService.employeesRef(companyId).doc(req.employeeId), {
            'leaveBalances.$balanceKey': FieldValue.increment(-effectiveDays),
          });
        }
      });

      if (alreadyHandledBy != null) {
        state = const AsyncValue.data(null);
        return 'Already handled by $alreadyHandledBy.';
      }

      // Write calendar entries + notification outside transaction (non-critical)
      final batch = db.batch();
      var current = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
      final last  = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
      while (!current.isAfter(last)) {
        final dayName = _dayName(current.weekday);
        final mmdd = '${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        if (workingDays.contains(dayName) && !AppConstants.rwandaHolidays.contains(mmdd)) {
          final dateStr = leaveDateKey(current);
          batch.set(FirebaseService.leavesCalendarRef(companyId).doc('${dateStr}_${req.employeeId}'), {
            'employeeId': req.employeeId, 'employeeName': req.employeeName,
            'date': dateStr, 'leaveType': req.leaveType, 'leaveRequestId': req.id,
          });
        }
        current = current.add(const Duration(days: 1));
      }
      batch.set(FirebaseService.notificationsRef(companyId).doc(), {
        'type': 'leave_approved', 'title': 'Leave Approved',
        'body': 'Your ${_typeLabel(req.leaveType)} leave has been approved.',
        'employeeId': req.employeeId, 'leaveRequestId': req.id,
        'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Transaction-guarded reject ─────────────────────────────────────────────
  Future<String?> rejectLeaveGuarded(LeaveRequestModel req, String reason) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final approverRole = _ref.read(currentUserRoleProvider) ?? 'manager';
      final db = FirebaseService.db;
      final reqRef = FirebaseService.leaveRef(companyId).doc(req.id);
      String? alreadyHandledBy;

      await db.runTransaction((tx) async {
        final snap = await tx.get(reqRef);
        final status = snap.data()?['status'] as String? ?? '';
        if (status != 'pending') {
          alreadyHandledBy = snap.data()?['approvedByRole'] ?? snap.data()?['rejectedByRole'] ?? 'someone';
          return;
        }
        tx.update(reqRef, {
          'status': 'rejected', 'rejectedReason': reason,
          'rejectedBy': _uid, 'rejectedByRole': approverRole,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      });

      if (alreadyHandledBy != null) {
        state = const AsyncValue.data(null);
        return 'Already handled by $alreadyHandledBy.';
      }

      await FirebaseService.notificationsRef(companyId).add({
        'type': 'leave_rejected', 'title': 'Leave Request Declined',
        'body': 'Your ${_typeLabel(req.leaveType)} leave was declined. Reason: $reason',
        'employeeId': req.employeeId, 'leaveRequestId': req.id,
        'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
      });
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── HR Admin override (reverse a decision with reason) ────────────────────
  Future<void> overrideLeaveDecision({
    required LeaveRequestModel req,
    required String newStatus, // 'approved' or 'rejected'
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final settings = _ref.read(companySettingsProvider).value;
      final workingDays = settings?.workingDays ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
      final db = FirebaseService.db;
      final batch = db.batch();
      final reqRef = FirebaseService.leaveRef(companyId).doc(req.id);

      if (newStatus == 'approved') {
        final recalcDays = WorkingDaysService.calculate(req.startDate, req.endDate, workingDays);
        final effectiveDays = recalcDays > 0 ? recalcDays : req.totalDays > 0 ? req.totalDays : 1;
        batch.update(reqRef, {
          'status': 'approved', 'approvedBy': _uid, 'approvedByRole': 'hr_admin',
          'approvedAt': FieldValue.serverTimestamp(), 'totalDays': effectiveDays,
          'overriddenBy': _uid, 'overrideReason': reason, 'overriddenAt': FieldValue.serverTimestamp(),
        });
        final balanceKey = _balanceKey(req.leaveType);
        if (balanceKey != null) {
          batch.update(FirebaseService.employeesRef(companyId).doc(req.employeeId), {
            'leaveBalances.$balanceKey': FieldValue.increment(-effectiveDays),
          });
        }
        var current = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
        final last = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
        while (!current.isAfter(last)) {
          final dayName = _dayName(current.weekday);
          final mmdd = '${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
          if (workingDays.contains(dayName) && !AppConstants.rwandaHolidays.contains(mmdd)) {
            final dateStr = leaveDateKey(current);
            batch.set(FirebaseService.leavesCalendarRef(companyId).doc('${dateStr}_${req.employeeId}'), {
              'employeeId': req.employeeId, 'employeeName': req.employeeName,
              'date': dateStr, 'leaveType': req.leaveType, 'leaveRequestId': req.id,
            });
          }
          current = current.add(const Duration(days: 1));
        }
      } else {
        // Override to rejected: restore balance, delete calendar docs
        batch.update(reqRef, {
          'status': 'rejected', 'rejectedReason': reason,
          'rejectedBy': _uid, 'rejectedByRole': 'hr_admin',
          'rejectedAt': FieldValue.serverTimestamp(),
          'overriddenBy': _uid, 'overrideReason': reason, 'overriddenAt': FieldValue.serverTimestamp(),
        });
        final balanceKey = _balanceKey(req.leaveType);
        if (balanceKey != null) {
          batch.update(FirebaseService.employeesRef(companyId).doc(req.employeeId), {
            'leaveBalances.$balanceKey': FieldValue.increment(req.totalDays),
          });
        }
        // Delete calendar entries
        final calDocs = await FirebaseService.leavesCalendarRef(companyId)
            .where('leaveRequestId', isEqualTo: req.id)
            .get();
        for (final d in calDocs.docs) { batch.delete(d.reference); }
      }

      batch.set(FirebaseService.notificationsRef(companyId).doc(), {
        'type': newStatus == 'approved' ? 'leave_approved' : 'leave_rejected',
        'title': newStatus == 'approved' ? 'Leave Approved (Override)' : 'Leave Rejected (Override)',
        'body': 'HR Admin has overridden your leave request. Reason: $reason',
        'employeeId': req.employeeId, 'leaveRequestId': req.id,
        'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── HR: mark employee on leave directly (source = hr_manual) ──────────────
  Future<void> hrMarkOnLeave({
    required String employeeId,
    required String employeeName,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? branchId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final settings = _ref.read(companySettingsProvider).value;
      final workingDays = settings?.workingDays ??
          const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

      final totalDays = WorkingDaysService.calculate(startDate, endDate, workingDays);
      final effectiveDays = totalDays > 0 ? totalDays : 1;

      final db = FirebaseService.db;
      final batch = db.batch();

      // 1. Create approved leave document
      final docRef = FirebaseService.leaveRef(companyId).doc();
      batch.set(docRef, {
        'companyId': companyId,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'leaveType': leaveType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalDays': effectiveDays,
        'reason': reason,
        'status': 'approved',
        'source': 'hr_manual',
        if (branchId != null) 'branchId': branchId,
        'approvedBy': _uid,
        'approvedByRole': 'hr_admin',
        'approvedAt': FieldValue.serverTimestamp(),
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // 2. Deduct leave balance
      final balanceKey = _balanceKey(leaveType);
      if (balanceKey != null) {
        batch.update(FirebaseService.employeesRef(companyId).doc(employeeId), {
          'leaveBalances.$balanceKey': FieldValue.increment(-effectiveDays),
        });
      }

      // 3. Write leaves_calendar entries for each working day
      var current = DateTime(startDate.year, startDate.month, startDate.day);
      final last = DateTime(endDate.year, endDate.month, endDate.day);
      while (!current.isAfter(last)) {
        final dayName = _dayName(current.weekday);
        final mmdd =
            '${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        if (workingDays.contains(dayName) &&
            !AppConstants.rwandaHolidays.contains(mmdd)) {
          final dateStr = leaveDateKey(current);
          batch.set(
              FirebaseService.leavesCalendarRef(companyId).doc('${dateStr}_$employeeId'), {
            'employeeId': employeeId,
            'employeeName': employeeName,
            'date': dateStr,
            'leaveType': leaveType,
            'leaveRequestId': docRef.id,
          });
        }
        current = current.add(const Duration(days: 1));
      }

      // 4. Notify employee
      batch.set(FirebaseService.notificationsRef(companyId).doc(), {
        'type': 'leave_approved',
        'title': 'Leave Recorded by HR',
        'body':
            '${_typeLabel(leaveType)} leave ($effectiveDays days) has been recorded for you by HR.',
        'employeeId': employeeId,
        'leaveRequestId': docRef.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────────
  Future<void> markNotificationRead(String notificationId) async {
    final companyId = _companyId;
    if (companyId == null) return;
    await FirebaseService.notificationsRef(companyId)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllRead() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final unread = await FirebaseService.notificationsRef(companyId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseService.db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _typeLabel(String type) => switch (type) {
        'annual' => 'Annual',
        'sick' => 'Sick',
        'maternity' => 'Maternity',
        'paternity' => 'Paternity',
        'unpaid' => 'Unpaid',
        'emergency' => 'Emergency',
        'compassionate' => 'Compassionate',
        _ => type,
      };

  String? _balanceKey(String type) => switch (type) {
        'annual' => 'annual',
        'sick' => 'sick',
        'maternity' => 'maternity',
        'paternity' => 'paternity',
        _ => null,
      };

  String _dayName(int weekday) => switch (weekday) {
        1 => 'monday',
        2 => 'tuesday',
        3 => 'wednesday',
        4 => 'thursday',
        5 => 'friday',
        6 => 'saturday',
        7 => 'sunday',
        _ => '',
      };
}

final leaveNotifierProvider =
    StateNotifierProvider<LeaveNotifier, AsyncValue<void>>(
  (ref) => LeaveNotifier(ref),
);
