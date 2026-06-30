class LeaveRequestModel {
  const LeaveRequestModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.source,
    required this.requestedAt,
    this.branchId,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    this.attachmentUrl,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final String status;
  final String source;
  final DateTime requestedAt;
  final String? branchId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final String? attachmentUrl;

  factory LeaveRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return LeaveRequestModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      leaveType: map['leaveType'] as String? ?? 'annual',
      startDate: _parseDate(map['startDate']),
      endDate: _parseDate(map['endDate']),
      totalDays: map['totalDays'] as int? ?? 0,
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      source: map['source'] as String? ?? 'mobile',
      requestedAt: _parseDate(map['requestedAt']),
      branchId: map['branchId'] as String?,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null ? _parseDate(map['approvedAt']) : null,
      rejectedReason: map['rejectedReason'] as String?,
      attachmentUrl: map['attachmentUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalDays': totalDays,
      'reason': reason,
      'status': status,
      'source': source,
      'requestedAt': requestedAt.toIso8601String(),
      if (branchId != null) 'branchId': branchId,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
      if (rejectedReason != null) 'rejectedReason': rejectedReason,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
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
