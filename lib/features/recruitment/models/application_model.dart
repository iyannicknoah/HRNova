class ApplicationModel {
  const ApplicationModel({
    required this.id,
    required this.companyId,
    required this.jobId,
    required this.jobTitle,
    required this.applicantName,
    required this.email,
    required this.phone,
    required this.status,
    required this.appliedAt,
    this.yearsExperience = 0,
    this.coverLetter,
    this.cvUrl,
    this.cvKey,
    this.certUrl,
    this.certKey,
    this.aiScore,
    this.aiQualificationScore,
    this.aiExperienceScore,
    this.aiSkillsScore,
    this.aiCommunicationScore,
    this.aiRecommendation,
    this.aiStrengths = const [],
    this.aiConcerns = const [],
    this.aiSummary,
    this.interviewDate,
    this.interviewTime,
    this.interviewLocation,
    this.rejectionConfirmedByHR = false,
    this.rejectionSentAt,
    this.interviewInviteSentAt,
  });

  final String id;
  final String companyId;
  final String jobId;
  final String jobTitle;
  final String applicantName;
  final String email;
  final String phone;
  final String status; // pending | shortlisted | declined | hired
  final DateTime appliedAt;
  final int yearsExperience;
  final String? coverLetter;
  final String? cvUrl;
  final String? cvKey;
  final String? certUrl;
  final String? certKey;

  // AI Scoring
  final double? aiScore; // 0-100 overall
  final double? aiQualificationScore;
  final double? aiExperienceScore;
  final double? aiSkillsScore;
  final double? aiCommunicationScore;
  final String? aiRecommendation; // accept | review | reject
  final List<String> aiStrengths;
  final List<String> aiConcerns;
  final String? aiSummary;

  // Interview
  final String? interviewDate;
  final String? interviewTime;
  final String? interviewLocation;

  // Rejection flow
  final bool rejectionConfirmedByHR;
  final DateTime? rejectionSentAt;
  final DateTime? interviewInviteSentAt;

  bool get hasAiScore => aiScore != null;

  String get recommendationLabel => switch (aiRecommendation) {
        'accept' => 'Strong Match',
        'review' => 'Review',
        'reject' => 'Not Suitable',
        _ => 'Pending',
      };

  factory ApplicationModel.fromMap(String id, Map<String, dynamic> map) {
    return ApplicationModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      appliedAt: _parseDate(map['appliedAt']),
      yearsExperience: map['yearsExperience'] as int? ?? 0,
      coverLetter: map['coverLetter'] as String?,
      cvUrl: map['cvUrl'] as String?,
      cvKey: map['cvKey'] as String?,
      certUrl: map['certUrl'] as String?,
      certKey: map['certKey'] as String?,
      aiScore: (map['aiScore'] as num?)?.toDouble(),
      aiQualificationScore: (map['aiQualificationScore'] as num?)?.toDouble(),
      aiExperienceScore: (map['aiExperienceScore'] as num?)?.toDouble(),
      aiSkillsScore: (map['aiSkillsScore'] as num?)?.toDouble(),
      aiCommunicationScore: (map['aiCommunicationScore'] as num?)?.toDouble(),
      aiRecommendation: map['aiRecommendation'] as String?,
      aiStrengths: (map['aiStrengths'] as List<dynamic>?)?.cast<String>() ?? [],
      aiConcerns: (map['aiConcerns'] as List<dynamic>?)?.cast<String>() ?? [],
      aiSummary: map['aiSummary'] as String?,
      interviewDate: map['interviewDate'] as String?,
      interviewTime: map['interviewTime'] as String?,
      interviewLocation: map['interviewLocation'] as String?,
      rejectionConfirmedByHR: map['rejectionConfirmedByHR'] as bool? ?? false,
      rejectionSentAt: map['rejectionSentAt'] != null ? _parseDate(map['rejectionSentAt']) : null,
      interviewInviteSentAt: map['interviewInviteSentAt'] != null ? _parseDate(map['interviewInviteSentAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'applicantName': applicantName,
        'email': email,
        'phone': phone,
        'status': status,
        'appliedAt': appliedAt.toIso8601String(),
        'yearsExperience': yearsExperience,
        if (coverLetter != null) 'coverLetter': coverLetter,
        if (cvUrl != null) 'cvUrl': cvUrl,
        if (cvKey != null) 'cvKey': cvKey,
        if (certUrl != null) 'certUrl': certUrl,
        if (certKey != null) 'certKey': certKey,
        if (aiScore != null) 'aiScore': aiScore,
        if (aiQualificationScore != null) 'aiQualificationScore': aiQualificationScore,
        if (aiExperienceScore != null) 'aiExperienceScore': aiExperienceScore,
        if (aiSkillsScore != null) 'aiSkillsScore': aiSkillsScore,
        if (aiCommunicationScore != null) 'aiCommunicationScore': aiCommunicationScore,
        if (aiRecommendation != null) 'aiRecommendation': aiRecommendation,
        'aiStrengths': aiStrengths,
        'aiConcerns': aiConcerns,
        if (aiSummary != null) 'aiSummary': aiSummary,
        if (interviewDate != null) 'interviewDate': interviewDate,
        if (interviewTime != null) 'interviewTime': interviewTime,
        if (interviewLocation != null) 'interviewLocation': interviewLocation,
        'rejectionConfirmedByHR': rejectionConfirmedByHR,
        if (rejectionSentAt != null) 'rejectionSentAt': rejectionSentAt!.toIso8601String(),
        if (interviewInviteSentAt != null) 'interviewInviteSentAt': interviewInviteSentAt!.toIso8601String(),
      };

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }
}
