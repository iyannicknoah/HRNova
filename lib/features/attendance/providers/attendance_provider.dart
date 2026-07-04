import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../models/attendance_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String attDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String attDocId(String employeeId, DateTime date) =>
    '${employeeId}_${attDateKey(date)}';

// ── Stream: all records for a specific date ───────────────────────────────────

final attendanceByDateProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, DateTime>((ref, date) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final dateStr = attDateKey(date);

  return FirebaseService.attendanceRef(companyId)
      .where('date', isEqualTo: dateStr)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AttendanceModel.fromMap(d.id, d.data()))
          .toList());
});

// ── Stream: all records for a given month ─────────────────────────────────────

typedef _MonthParam = ({int year, int month});

final attendanceByMonthProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, _MonthParam>((ref, p) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);

  final start = '${p.year}-${p.month.toString().padLeft(2, '0')}-01';
  final endMonth = p.month == 12 ? 1 : p.month + 1;
  final endYear = p.month == 12 ? p.year + 1 : p.year;
  final end = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

  return FirebaseService.attendanceRef(companyId)
      .where('date', isGreaterThanOrEqualTo: start)
      .where('date', isLessThan: end)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AttendanceModel.fromMap(d.id, d.data()))
          .toList());
});

// ── Stream: one employee's records for a given month ─────────────────────────

typedef _EmpMonthParam = ({String employeeId, int year, int month});

final employeeAttendanceByMonthProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, _EmpMonthParam>((ref, p) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);

  final start = '${p.year}-${p.month.toString().padLeft(2, '0')}-01';
  final endMonth = p.month == 12 ? 1 : p.month + 1;
  final endYear = p.month == 12 ? p.year + 1 : p.year;
  final end = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

  return FirebaseService.attendanceRef(companyId)
      .where('employeeId', isEqualTo: p.employeeId)
      .where('date', isGreaterThanOrEqualTo: start)
      .where('date', isLessThan: end)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AttendanceModel.fromMap(d.id, d.data()))
          .toList());
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class AttendanceNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  String? get _companyId => _ref.read(currentCompanyIdProvider);
  String? get _uid => FirebaseService.currentUserId;

  // Parse a time string like '08:00' → (hour, minute)
  (int, int) _parseHHMM(String time, {int defaultH = 0}) {
    final parts = time.split(':');
    if (parts.length != 2) return (defaultH, 0);
    return (int.tryParse(parts[0]) ?? defaultH, int.tryParse(parts[1]) ?? 0);
  }

  // Check in — called from guard mode (QR scan) or manual
  Future<AttendanceModel> checkIn({
    required String employeeId,
    String? branchId,
    DateTime? time,
    bool isManual = false,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final now = time ?? DateTime.now();
      final dateStr = attDateKey(now);
      final docId = attDocId(employeeId, now);

      final settings = _ref.read(companySettingsProvider).value;
      final workStartStr = settings?.workStartTime ?? '08:00';
      final workEndStr   = settings?.workEndTime   ?? '17:00';
      final gracePeriod  = settings?.gracePeriodMinutes ?? 10;

      final (sh, sm) = _parseHHMM(workStartStr, defaultH: 8);
      final (eh, em) = _parseHHMM(workEndStr,   defaultH: 17);

      final workStart = DateTime(now.year, now.month, now.day, sh, sm);
      final workEnd   = DateTime(now.year, now.month, now.day, eh, em);

      // Check-in AFTER work hours end → mark as absent
      if (now.isAfter(workEnd)) {
        final data = <String, dynamic>{
          'companyId': companyId,
          'employeeId': employeeId,
          if (branchId != null) 'branchId': branchId,
          'date': dateStr,
          'verificationType': isManual ? 'manual' : 'qr_scan',
          if (!isManual) 'guardUid': _uid,
          'isLate': false,
          'lateMinutes': 0,
          'isAbsent': true,
          'isOnLeave': false,
          'notes': 'Check-in attempted after work hours ended (${workEndStr})',
          'createdAt': FieldValue.serverTimestamp(),
        };
        await FirebaseService.attendanceRef(companyId)
            .doc(docId)
            .set(data, SetOptions(merge: true));
        state = const AsyncValue.data(null);
        return AttendanceModel.fromMap(docId, data);
      }

      final gracedStart = workStart.add(Duration(minutes: gracePeriod));
      final isLate = now.isAfter(gracedStart);
      final lateMinutes = isLate ? now.difference(workStart).inMinutes : 0;

      final data = <String, dynamic>{
        'companyId': companyId,
        'employeeId': employeeId,
        if (branchId != null) 'branchId': branchId,
        'date': dateStr,
        'checkInTime': now.toIso8601String(),
        'verificationType': isManual ? 'manual' : 'qr_scan',
        if (!isManual) 'guardUid': _uid,
        'isLate': isLate,
        'lateMinutes': lateMinutes,
        'isAbsent': false,
        'isOnLeave': false,
        if (notes != null) 'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseService.attendanceRef(companyId)
          .doc(docId)
          .set(data, SetOptions(merge: true));

      state = const AsyncValue.data(null);
      return AttendanceModel.fromMap(docId, data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Check out — called from guard mode after detecting already-checked-in employee
  Future<void> checkOut({
    required String employeeId,
    DateTime? time,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final now = time ?? DateTime.now();
      final docId = attDocId(employeeId, now);

      // Compute working hours from stored checkInTime
      final doc =
          await FirebaseService.attendanceRef(companyId).doc(docId).get();
      double? workingHours;
      if (doc.exists) {
        final ciStr = doc.data()?['checkInTime'] as String?;
        final ci = ciStr != null ? DateTime.tryParse(ciStr) : null;
        if (ci != null) {
          workingHours =
              double.parse((now.difference(ci).inMinutes / 60).toStringAsFixed(2));
        }
      }

      await FirebaseService.attendanceRef(companyId).doc(docId).update({
        'checkOutTime': now.toIso8601String(),
        if (workingHours != null) 'workingHours': workingHours,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Manual entry (HR admin) — creates or overwrites a record
  Future<void> addManualEntry({
    required String employeeId,
    String? branchId,
    required DateTime date,
    required DateTime checkInTime,
    DateTime? checkOutTime,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');

      final settings = _ref.read(companySettingsProvider).value;
      final workStartStr = settings?.workStartTime ?? '08:00';
      final gracePeriod = settings?.gracePeriodMinutes ?? 10;
      final (sh, sm) = _parseHHMM(workStartStr);

      final workStart = DateTime(date.year, date.month, date.day, sh, sm);
      final gracedStart = workStart.add(Duration(minutes: gracePeriod));
      final isLate = checkInTime.isAfter(gracedStart);
      final lateMinutes =
          isLate ? checkInTime.difference(workStart).inMinutes : 0;

      double? workingHours;
      if (checkOutTime != null) {
        workingHours = double.parse(
            (checkOutTime.difference(checkInTime).inMinutes / 60)
                .toStringAsFixed(2));
      }

      final docId = attDocId(employeeId, date);
      await FirebaseService.attendanceRef(companyId).doc(docId).set({
        'companyId': companyId,
        'employeeId': employeeId,
        if (branchId != null) 'branchId': branchId,
        'date': attDateKey(date),
        'checkInTime': checkInTime.toIso8601String(),
        if (checkOutTime != null) 'checkOutTime': checkOutTime.toIso8601String(),
        if (workingHours != null) 'workingHours': workingHours,
        'verificationType': 'manual',
        'recordedBy': _uid,
        'isLate': isLate,
        'lateMinutes': lateMinutes,
        'isAbsent': false,
        'isOnLeave': false,
        if (notes != null) 'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Mark on leave
  Future<void> markOnLeave({
    required String employeeId,
    String? branchId,
    required DateTime date,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated.');
      final docId = attDocId(employeeId, date);

      await FirebaseService.attendanceRef(companyId).doc(docId).set({
        'companyId': companyId,
        'employeeId': employeeId,
        if (branchId != null) 'branchId': branchId,
        'date': attDateKey(date),
        'verificationType': 'manual',
        'recordedBy': _uid,
        'isAbsent': false,
        'isOnLeave': true,
        'isLate': false,
        'lateMinutes': 0,
        if (notes != null) 'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Fetch today's record for a single employee (used by guard mode)
  Future<AttendanceModel?> getTodayRecord(String employeeId) async {
    final companyId = _companyId;
    if (companyId == null) return null;
    final docId = attDocId(employeeId, DateTime.now());
    final doc =
        await FirebaseService.attendanceRef(companyId).doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AttendanceModel.fromMap(doc.id, doc.data()!);
  }
}

final attendanceNotifierProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<void>>(
  (ref) => AttendanceNotifier(ref),
);
