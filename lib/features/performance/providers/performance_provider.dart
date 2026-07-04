import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/api_service.dart';
import '../models/performance_model.dart';

// Stream all scores for a given month
final performanceByMonthProvider = StreamProvider.autoDispose
    .family<List<PerformanceModel>, String>((ref, month) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.performanceRef(companyId)
      .where('month', isEqualTo: month)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => PerformanceModel.fromMap(d.id, d.data())).toList());
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
