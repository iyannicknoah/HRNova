import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String firstName;
  final String lastName;
  final String nationalId;
  final String phone;
  final String email;
  final String department;
  final String jobTitle;
  final String contractType; // permanent | fixed_term | probation
  final DateTime startDate;
  final DateTime? endDate;
  final String salaryType; // fixed_monthly | daily_rate | hourly_rate
  final double salaryAmount;
  final double dailyRate;
  final String role; // employee | manager | hr_admin
  final String qrCode;
  final String status; // active | inactive
  final Map<String, int> leaveBalances; // annual, sick, maternity, paternity
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nationalId,
    required this.phone,
    required this.email,
    required this.department,
    required this.jobTitle,
    required this.contractType,
    required this.startDate,
    this.endDate,
    required this.salaryType,
    required this.salaryAmount,
    required this.dailyRate,
    required this.role,
    required this.qrCode,
    required this.status,
    required this.leaveBalances,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Employee(
      id: doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      nationalId: data['nationalId'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      department: data['department'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? '',
      contractType: data['contractType'] as String? ?? 'permanent',
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      salaryType: data['salaryType'] as String? ?? 'fixed_monthly',
      salaryAmount: (data['salaryAmount'] as num? ?? 0.0).toDouble(),
      dailyRate: (data['dailyRate'] as num? ?? 0.0).toDouble(),
      role: data['role'] as String? ?? 'employee',
      qrCode: data['qrCode'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      leaveBalances: Map<String, int>.from(data['leaveBalances'] ?? {
        'annual': 18,
        'sick': 10,
        'maternity': 84,
        'paternity': 4,
      }),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'nationalId': nationalId,
      'phone': phone,
      'email': email,
      'department': department,
      'jobTitle': jobTitle,
      'contractType': contractType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'salaryType': salaryType,
      'salaryAmount': salaryAmount,
      'dailyRate': dailyRate,
      'role': role,
      'qrCode': qrCode,
      'status': status,
      'leaveBalances': leaveBalances,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Employee copyWith({
    String? firstName,
    String? lastName,
    String? nationalId,
    String? phone,
    String? email,
    String? department,
    String? jobTitle,
    String? contractType,
    DateTime? startDate,
    DateTime? endDate,
    String? salaryType,
    double? salaryAmount,
    double? dailyRate,
    String? role,
    String? qrCode,
    String? status,
    Map<String, int>? leaveBalances,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nationalId: nationalId ?? this.nationalId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      contractType: contractType ?? this.contractType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      dailyRate: dailyRate ?? this.dailyRate,
      role: role ?? this.role,
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      leaveBalances: leaveBalances ?? this.leaveBalances,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
