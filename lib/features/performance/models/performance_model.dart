import '../../settings/models/company_settings_model.dart';

class PerformanceModel {
  const PerformanceModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    this.branchId,
    required this.month,
    required this.scores,
    required this.overallScore,
    this.aiReview,
    this.managerNotes,
    required this.scoredBy,
    required this.scoredAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String? branchId;
  final String month; // YYYY-MM
  final Map<String, double> scores; // criteriaName → 1-5
  final double overallScore; // weighted average
  final String? aiReview;
  final String? managerNotes;
  final String scoredBy;
  final DateTime scoredAt;

  static String docId(String employeeId, String month) => '${employeeId}_$month';

  factory PerformanceModel.fromMap(String id, Map<String, dynamic> m) {
    return PerformanceModel(
      id: id,
      employeeId: m['employeeId'] as String? ?? '',
      employeeName: m['employeeName'] as String? ?? '',
      department: m['department'] as String? ?? '',
      branchId: m['branchId'] as String?,
      month: m['month'] as String? ?? '',
      scores: (m['scores'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      overallScore: (m['overallScore'] as num?)?.toDouble() ?? 0,
      aiReview: m['aiReview'] as String?,
      managerNotes: m['managerNotes'] as String?,
      scoredBy: m['scoredBy'] as String? ?? '',
      scoredAt: _parseDate(m['scoredAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'employeeName': employeeName,
    'department': department,
    if (branchId != null) 'branchId': branchId,
    'month': month,
    'scores': scores,
    'overallScore': overallScore,
    if (aiReview != null) 'aiReview': aiReview,
    if (managerNotes != null) 'managerNotes': managerNotes,
    'scoredBy': scoredBy,
    'scoredAt': scoredAt.toIso8601String(),
  };

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Compute weighted average from scores + criteria
  static double computeOverall(
      Map<String, double> scores, List<PerformanceCriterion> criteria) {
    double total = 0;
    double weightSum = 0;
    for (final c in criteria) {
      final s = scores[c.name];
      if (s != null) {
        total += s * c.weight;
        weightSum += c.weight;
      }
    }
    return weightSum > 0 ? total / weightSum : 0;
  }
}
