class PerformanceModel {
  const PerformanceModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.period,
    required this.overallScore,
    required this.kpis,
    this.branchId,
    this.reviewedBy,
    this.aiSummary,
    this.managerComments,
    this.employeeComments,
    this.status = 'draft',
    this.rank,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String period;
  final double overallScore;
  final List<KpiEntry> kpis;
  final String? branchId;
  final String? reviewedBy;
  final String? aiSummary;
  final String? managerComments;
  final String? employeeComments;
  final String status;
  final int? rank;

  factory PerformanceModel.fromMap(String id, Map<String, dynamic> map) {
    final kpiList = (map['kpis'] as List<dynamic>? ?? [])
        .map((k) => KpiEntry.fromMap(k as Map<String, dynamic>))
        .toList();
    return PerformanceModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      period: map['period'] as String? ?? '',
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0,
      kpis: kpiList,
      branchId: map['branchId'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      aiSummary: map['aiSummary'] as String?,
      managerComments: map['managerComments'] as String?,
      employeeComments: map['employeeComments'] as String?,
      status: map['status'] as String? ?? 'draft',
      rank: map['rank'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'period': period,
      'overallScore': overallScore,
      'kpis': kpis.map((k) => k.toMap()).toList(),
      if (branchId != null) 'branchId': branchId,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (aiSummary != null) 'aiSummary': aiSummary,
      if (managerComments != null) 'managerComments': managerComments,
      if (employeeComments != null) 'employeeComments': employeeComments,
      'status': status,
      if (rank != null) 'rank': rank,
    };
  }
}

class KpiEntry {
  const KpiEntry({
    required this.name,
    required this.target,
    required this.actual,
    required this.score,
    this.weight = 1,
    this.notes,
  });

  final String name;
  final double target;
  final double actual;
  final double score;
  final double weight;
  final String? notes;

  factory KpiEntry.fromMap(Map<String, dynamic> map) {
    return KpiEntry(
      name: map['name'] as String? ?? '',
      target: (map['target'] as num?)?.toDouble() ?? 0,
      actual: (map['actual'] as num?)?.toDouble() ?? 0,
      score: (map['score'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 1,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'target': target,
        'actual': actual,
        'score': score,
        'weight': weight,
        if (notes != null) 'notes': notes,
      };
}
