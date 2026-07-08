import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/models/attendance_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employees/models/employee_model.dart';
import '../../settings/models/company_settings_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/api_service.dart';
import '../models/performance_model.dart';

// Stream all scores for a given month (scoped for manager by branchId)
final performanceByMonthProvider = StreamProvider.autoDispose
    .family<List<PerformanceModel>, String>((ref, month) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  final role     = ref.watch(currentUserRoleProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  Query<Map<String, dynamic>> q = FirebaseService.performanceRef(companyId)
      .where('month', isEqualTo: month);
  if (role == AppConstants.roleManager && branchId != null) {
    q = q.where('branchId', isEqualTo: branchId);
  }
  return q.snapshots()
      .map((s) => s.docs.map((d) => PerformanceModel.fromMap(d.id, d.data())).toList());
});

// Stream all scores for one employee (history)
final employeePerformanceProvider = StreamProvider.autoDispose
    .family<List<PerformanceModel>, String>((ref, employeeId) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.performanceRef(companyId)
      .where('employeeId', isEqualTo: employeeId)
      .orderBy('month', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => PerformanceModel.fromMap(d.id, d.data())).toList());
});

class PerformanceNotifier extends StateNotifier<AsyncValue<void>> {
  PerformanceNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  String? get _companyId => _ref.read(currentCompanyIdProvider);

  // In-session guard: don't re-compute auto-scores already done this session
  final _autoScoredThisSession = <String>{};

  static const _attendancePunctualityKey = 'Attendance and Punctuality';

  /// Auto-computes Attendance & Punctuality score from recorded attendance.
  /// Writes to Firestore with merge: true, preserving any existing manual scores.
  Future<void> autoScoreAttendance({
    required EmployeeModel employee,
    required String month,
    required List<AttendanceModel> records,
    required List<PerformanceCriterion> criteria,
    required Map<String, PerformanceModel> existingScoreMap,
  }) async {
    final sessionKey = '${employee.id}_$month';
    if (_autoScoredThisSession.contains(sessionKey)) return;

    final existing = existingScoreMap[employee.id];
    if (existing != null && existing.systemScoredKeys.contains(_attendancePunctualityKey)) {
      _autoScoredThisSession.add(sessionKey);
      return; // already auto-scored for this month
    }

    final workingRecords = records.where((r) => !r.isOnLeave).toList();
    if (workingRecords.isEmpty) return; // no attendance data yet

    final totalDays    = workingRecords.length;
    final presentDays  = workingRecords.where((r) => !r.isAbsent).length;
    final lateDays     = workingRecords.where((r) => !r.isAbsent && r.isLate).length;
    final onTimeDays   = presentDays - lateDays;

    final attendanceRate  = totalDays > 0 ? presentDays / totalDays : 0.0;
    final punctualityRate = presentDays > 0 ? onTimeDays / presentDays : 0.0;

    final attendanceScore  = (attendanceRate  * 5).clamp(1.0, 5.0);
    final punctualityScore = (punctualityRate * 5).clamp(1.0, 5.0);
    final combinedScore    = double.parse(
      ((attendanceScore + punctualityScore) / 2).clamp(1.0, 5.0).toStringAsFixed(1),
    );

    final companyId = _companyId;
    if (companyId == null) return;

    _autoScoredThisSession.add(sessionKey);

    final scores = Map<String, double>.from(existing?.scores ?? {});
    scores[_attendancePunctualityKey] = combinedScore;
    final overall = PerformanceModel.computeOverall(scores, criteria);
    final now     = DateTime.now();

    await FirebaseService.performanceRef(companyId)
        .doc(PerformanceModel.docId(employee.id, month))
        .set({
      'employeeId':        employee.id,
      'employeeName':      employee.fullName,
      'department':        employee.department,
      if (employee.branchId != null) 'branchId': employee.branchId,
      'month':             month,
      'scores':            scores,
      'overallScore':      overall,
      'systemScoredKeys':  [_attendancePunctualityKey],
      'scoredBy':          existing?.scoredBy ?? 'system',
      'scoredAt':          existing?.scoredAt.toIso8601String() ?? now.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> saveScore(PerformanceModel model) async {
    state = const AsyncValue.loading();
    try {
      final companyId = _companyId;
      if (companyId == null) throw Exception('Not authenticated');
      final docId = PerformanceModel.docId(model.employeeId, model.month);
      await FirebaseService.performanceRef(companyId)
          .doc(docId)
          .set(model.toMap(), SetOptions(merge: true));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> generateReview({
    required String employeeName,
    required String jobTitle,
    required List<Map<String, dynamic>> criteria,
    required Map<String, double> scores,
    required double overallScore,
  }) async {
    final response = await ApiService().post('/api/ai/generate-review', data: {
      'employeeName': employeeName,
      'jobTitle': jobTitle,
      'criteria': criteria,
      'scores': scores,
      'overallScore': overallScore,
    });
    return response.data['review'] as String;
  }

  Future<String> generateAnnualReport({
    required String employeeId,
    required String employeeName,
    required String jobTitle,
    required String department,
  }) async {
    final companyId = _companyId;
    if (companyId == null) throw Exception('Not authenticated');

    final snapshot = await FirebaseService.performanceRef(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('month')
        .get();
    final records = snapshot.docs
        .map((d) => PerformanceModel.fromMap(d.id, d.data()))
        .toList();
    final monthlyScores = records
        .map((r) => {'month': r.month, 'score': r.overallScore})
        .toList();

    final response =
        await ApiService().post('/api/ai/annual-performance', data: {
      'employee': {
        'name': employeeName,
        'jobTitle': jobTitle,
        'department': department,
      },
      'monthlyScores': monthlyScores,
      'attendanceSummary': {},
    });
    return response.data['narrative'] as String;
  }
}

final performanceNotifierProvider =
    StateNotifierProvider<PerformanceNotifier, AsyncValue<void>>(
  (ref) => PerformanceNotifier(ref),
);
