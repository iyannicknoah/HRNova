class ApplicationModel {
  const ApplicationModel({
    required this.id,
    required this.companyId,
    required this.jobId,
    required this.applicantName,
    required this.email,
    required this.phone,
    required this.status,
    required this.appliedAt,
    this.cvUrl,
    this.coverLetter,
    this.aiScore,
    this.aiSummary,
    this.aiStrengths,
    this.aiWeaknesses,
    this.interviewDate,
    this.interviewNotes,
    this.reviewedBy,
    this.linkedIn,
    this.currentPosition,
    this.yearsExperience,
  });

  final String id;
  final String companyId;
  final String jobId;
  final String applicantName;
  final String email;
  final String phone;
  final String status;
  final DateTime appliedAt;
  final String? cvUrl;
  final String? coverLetter;
  final double? aiScore;
  final String? aiSummary;
  final List<String>? aiStrengths;
  final List<String>? aiWeaknesses;
  final DateTime? interviewDate;
  final String? interviewNotes;
  final String? reviewedBy;
  final String? linkedIn;
  final String? currentPosition;
  final int? yearsExperience;

  factory ApplicationModel.fromMap(String id, Map<String, dynamic> map) {
    return ApplicationModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      appliedAt: _parseDate(map['appliedAt']),
      cvUrl: map['cvUrl'] as String?,
      coverLetter: map['coverLetter'] as String?,
      aiScore: (map['aiScore'] as num?)?.toDouble(),
      aiSummary: map['aiSummary'] as String?,
      aiStrengths: (map['aiStrengths'] as List<dynamic>?)?.cast<String>(),
      aiWeaknesses: (map['aiWeaknesses'] as List<dynamic>?)?.cast<String>(),
      interviewDate: map['interviewDate'] != null ? _parseDate(map['interviewDate']) : null,
      interviewNotes: map['interviewNotes'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      linkedIn: map['linkedIn'] as String?,
      currentPosition: map['currentPosition'] as String?,
      yearsExperience: map['yearsExperience'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'jobId': jobId,
      'applicantName': applicantName,
      'email': email,
      'phone': phone,
      'status': status,
      'appliedAt': appliedAt.toIso8601String(),
      if (cvUrl != null) 'cvUrl': cvUrl,
      if (coverLetter != null) 'coverLetter': coverLetter,
      if (aiScore != null) 'aiScore': aiScore,
      if (aiSummary != null) 'aiSummary': aiSummary,
      if (aiStrengths != null) 'aiStrengths': aiStrengths,
      if (aiWeaknesses != null) 'aiWeaknesses': aiWeaknesses,
      if (interviewDate != null) 'interviewDate': interviewDate!.toIso8601String(),
      if (interviewNotes != null) 'interviewNotes': interviewNotes,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (linkedIn != null) 'linkedIn': linkedIn,
      if (currentPosition != null) 'currentPosition': currentPosition,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
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
