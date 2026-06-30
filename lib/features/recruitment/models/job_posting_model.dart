class JobPostingModel {
  const JobPostingModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.department,
    required this.description,
    required this.requirements,
    required this.status,
    required this.postedAt,
    this.branchId,
    this.companyName,
    this.companySlug,
    this.jobSlug,
    this.salaryMin,
    this.salaryMax,
    this.contractType,
    this.location,
    this.closingDate,
    this.applicationCount = 0,
    this.isPublic = true,
  });

  final String id;
  final String companyId;
  final String title;
  final String department;
  final String description;
  final String requirements;
  final String status;
  final DateTime postedAt;
  final String? branchId;
  final String? companyName;
  final String? companySlug;
  final String? jobSlug;
  final double? salaryMin;
  final double? salaryMax;
  final String? contractType;
  final String? location;
  final DateTime? closingDate;
  final int applicationCount;
  final bool isPublic;

  factory JobPostingModel.fromMap(String id, Map<String, dynamic> map) {
    return JobPostingModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      department: map['department'] as String? ?? '',
      description: map['description'] as String? ?? '',
      requirements: map['requirements'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      postedAt: _parseDate(map['postedAt']),
      branchId: map['branchId'] as String?,
      companyName: map['companyName'] as String?,
      companySlug: map['companySlug'] as String?,
      jobSlug: map['jobSlug'] as String?,
      salaryMin: (map['salaryMin'] as num?)?.toDouble(),
      salaryMax: (map['salaryMax'] as num?)?.toDouble(),
      contractType: map['contractType'] as String?,
      location: map['location'] as String?,
      closingDate: map['closingDate'] != null ? _parseDate(map['closingDate']) : null,
      applicationCount: map['applicationCount'] as int? ?? 0,
      isPublic: map['isPublic'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'title': title,
      'department': department,
      'description': description,
      'requirements': requirements,
      'status': status,
      'postedAt': postedAt.toIso8601String(),
      if (branchId != null) 'branchId': branchId,
      if (companyName != null) 'companyName': companyName,
      if (companySlug != null) 'companySlug': companySlug,
      if (jobSlug != null) 'jobSlug': jobSlug,
      if (salaryMin != null) 'salaryMin': salaryMin,
      if (salaryMax != null) 'salaryMax': salaryMax,
      if (contractType != null) 'contractType': contractType,
      if (location != null) 'location': location,
      if (closingDate != null) 'closingDate': closingDate!.toIso8601String(),
      'applicationCount': applicationCount,
      'isPublic': isPublic,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
