import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/working_days_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/leave_request_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String leaveDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Stream: pending requests ──────────────────────────────────────────────────

final pendingLeaveRequestsProvider =
    StreamProvider.autoDispose<List<LeaveRequestModel>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.leaveRef(companyId)
      .where('status', isEqualTo: 'pending')
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
  return FirebaseService.leaveRef(companyId)
      .orderBy('requestedAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LeaveRequestModel.fromMap(d.id, d.data())).toList());
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

      // 1. Update request status
      batch.update(FirebaseService.leaveRef(companyId).doc(req.id), {
        'status': 'approved',
        'approvedBy': _uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // 2. Deduct balance (annual, sick, maternity, paternity only)
      final balanceKey = _balanceKey(req.leaveType);
      if (balanceKey != null) {
        batch.update(
            FirebaseService.employeesRef(companyId).doc(req.employeeId), {
          'leaveBalances.$balanceKey': FieldValue.increment(-req.totalDays),
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
            'Your ${_typeLabel(req.leaveType)} leave (${req.totalDays} days) has been approved.',
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

      batch.update(FirebaseService.leaveRef(companyId).doc(req.id), {
        'status': 'rejected',
        'rejectedReason': reason,
        'rejectedBy': _uid,
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

  // ── Manual balance adjustment (HR) ──────────────────────────────────────────
  Future<void> adjustLeaveBalance({
    required String employeeId,
    required String leaveType,
    required int newBalance,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final key = _balanceKey(leaveType) ?? leaveType;
      await FirebaseService.employeesRef(companyId)
          .doc(employeeId)
          .update({'leaveBalances.$key': newBalance});
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
