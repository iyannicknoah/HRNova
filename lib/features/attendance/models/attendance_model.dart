class AttendanceModel {
  const AttendanceModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.verificationType = 'manual',
    this.branchId,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    this.isLate = false,
    this.lateMinutes = 0,
    this.isAbsent = false,
    this.isOnLeave = false,
    this.notes,
    this.workingHours,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String verificationType;
  final String? branchId;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final bool isLate;
  final int lateMinutes;
  final bool isAbsent;
  final bool isOnLeave;
  final String? notes;
  final double? workingHours;

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      date: _parseDate(map['date']),
      checkInTime: map['checkInTime'] != null ? _parseDate(map['checkInTime']) : null,
      checkOutTime: map['checkOutTime'] != null ? _parseDate(map['checkOutTime']) : null,
      verificationType: map['verificationType'] as String? ?? 'manual',
      branchId: map['branchId'] as String?,
      checkInPhotoUrl: map['checkInPhotoUrl'] as String?,
      checkOutPhotoUrl: map['checkOutPhotoUrl'] as String?,
      isLate: map['isLate'] as bool? ?? false,
      lateMinutes: map['lateMinutes'] as int? ?? 0,
      isAbsent: map['isAbsent'] as bool? ?? false,
      isOnLeave: map['isOnLeave'] as bool? ?? false,
      notes: map['notes'] as String?,
      workingHours: (map['workingHours'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'employeeId': employeeId,
      'date': date.toIso8601String(),
      if (checkInTime != null) 'checkInTime': checkInTime!.toIso8601String(),
      if (checkOutTime != null) 'checkOutTime': checkOutTime!.toIso8601String(),
      'verificationType': verificationType,
      if (branchId != null) 'branchId': branchId,
      if (checkInPhotoUrl != null) 'checkInPhotoUrl': checkInPhotoUrl,
      if (checkOutPhotoUrl != null) 'checkOutPhotoUrl': checkOutPhotoUrl,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'isAbsent': isAbsent,
      'isOnLeave': isOnLeave,
      if (notes != null) 'notes': notes,
      if (workingHours != null) 'workingHours': workingHours,
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
