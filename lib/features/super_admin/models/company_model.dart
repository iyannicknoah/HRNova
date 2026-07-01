import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String name;
  final String slug;
  final String companyType;
  final String industry;
  final String status;
  final String hrAdminEmail;
  final String contactPerson;
  final String hrAdminPhone;
  final String address;
  final String tinNumber;
  final int monthlyPrice;
  final int employeeCount;
  final DateTime? createdAt;
  final String? lastPaymentDate;
  final int? lastPaymentAmount;

  const CompanyModel({
    required this.id,
    required this.name,
    this.slug = '',
    required this.companyType,
    this.industry = '',
    required this.status,
    required this.hrAdminEmail,
    this.contactPerson = '',
    this.hrAdminPhone = '',
    this.address = '',
    this.tinNumber = '',
    this.monthlyPrice = 0,
    this.employeeCount = 0,
    this.createdAt,
    this.lastPaymentDate,
    this.lastPaymentAmount,
  });

  bool get isMulti  => companyType == 'multi_branch';
  bool get isActive => status == 'active';

  factory CompanyModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CompanyModel(
      id:            doc.id,
      name:          d['name']           as String? ?? '',
      slug:          d['slug']           as String? ?? '',
      companyType:   d['companyType']    as String? ?? 'single',
      industry:      d['industry']       as String? ?? '',
      status:        d['status']         as String? ?? 'active',
      hrAdminEmail:  d['hrAdminEmail']   as String? ?? '',
      contactPerson: d['contactPerson']  as String? ?? '',
      hrAdminPhone:  d['hrAdminPhone']   as String? ?? '',
      address:       d['address']        as String? ?? '',
      tinNumber:     d['tinNumber']      as String? ?? '',
      monthlyPrice:  (d['monthlyPrice']  as num?)?.toInt() ?? 0,
      employeeCount: (d['employeeCount'] as num?)?.toInt() ?? 0,
      createdAt:          (d['createdAt'] as Timestamp?)?.toDate(),
      lastPaymentDate:     d['lastPaymentDate']    as String?,
      lastPaymentAmount:   d['lastPaymentAmount']  as int?,
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                           'Jul','Aug','Sep','Oct','Nov','Dec'];

  String get createdAtFormatted {
    if (createdAt == null) return '—';
    return '${_months[createdAt!.month - 1]} ${createdAt!.day}, ${createdAt!.year}';
  }
}
