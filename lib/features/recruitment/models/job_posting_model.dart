class JobPostingModel {
  const JobPostingModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.department,
    required this.description,
    required this.requirements,
    required this.status,
    required this.createdAt,
    this.requiredSkills = const [],
    this.minExperience = 0,
    this.aiCriteria,
    this.salaryMin,
    this.salaryMax,
    this.showSalary = false,
    this.deadline,
    this.companySlug,
    this.jobSlug,
    this.publicUrl,
    this.companyName,
    this.totalApplications = 0,
    this.shortlistedCount = 0,
  });

  final String id;
  final String companyId;
  final String title;
  final String department;
  final String description;
  final String requirements;
  final String status; // draft | open | closed
  final DateTime createdAt;
  final List<String> requiredSkills;
  final int minExperience;
  final String? aiCriteria;
  final double? salaryMin;
  final double? salaryMax;
  final bool showSalary;
  final DateTime? deadline;
  final String? companySlug;
  final String? jobSlug;
  final String? publicUrl;
  final String? companyName;
  final int totalApplications;
  final int shortlistedCount;

  String get publicLink =>
      publicUrl ?? (companySlug != null && jobSlug != null
          ? 'https://hrnova-6b7d8.web.app/apply/$companySlug/$jobSlug'
          : '');

  factory JobPostingModel.fromMap(String id, Map<String, dynamic> map) {
    return JobPostingModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      department: map['department'] as String? ?? '',
      description: map['description'] as String? ?? '',
      requirements: map['requirements'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      createdAt: _parseDate(map['createdAt']),
      requiredSkills: (map['requiredSkills'] as List<dynamic>?)?.cast<String>() ?? [],
      minExperience: map['minExperience'] as int? ?? 0,
      aiCriteria: map['aiCriteria'] as String?,
      salaryMin: (map['salaryMin'] as num?)?.toDouble(),
      salaryMax: (map['salaryMax'] as num?)?.toDouble(),
      showSalary: map['showSalary'] as bool? ?? false,
      deadline: map['deadline'] != null ? _parseDate(map['deadline']) : null,
      companySlug: map['companySlug'] as String?,
      jobSlug: map['jobSlug'] as String?,
      publicUrl: map['publicUrl'] as String?,
      companyName: map['companyName'] as String?,
      totalApplications: map['totalApplications'] as int? ?? 0,
      shortlistedCount: map['shortlistedCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'title': title,
        'department': department,
        'description': description,
        'requirements': requirements,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'requiredSkills': requiredSkills,
        'minExperience': minExperience,
        if (aiCriteria != null) 'aiCriteria': aiCriteria,
        if (salaryMin != null) 'salaryMin': salaryMin,
        if (salaryMax != null) 'salaryMax': salaryMax,
        'showSalary': showSalary,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        if (companySlug != null) 'companySlug': companySlug,
        if (jobSlug != null) 'jobSlug': jobSlug,
        if (publicUrl != null) 'publicUrl': publicUrl,
        if (companyName != null) 'companyName': companyName,
        'totalApplications': totalApplications,
        'shortlistedCount': shortlistedCount,
      };

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }
}
