import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  final String id;
  final String companyId;
  final String name;
  final String location;
  final String code;
  final String status;
  final DateTime? createdAt;

  const BranchModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.location = '',
    this.code = '',
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status == 'active';

  factory BranchModel.fromDoc(String companyId, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BranchModel(
      id:        doc.id,
      companyId: companyId,
      name:      d['name']     as String? ?? '',
      location:  d['location'] as String? ?? '',
      code:      d['code']     as String? ?? '',
      status:    d['status']   as String? ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                           'Jul','Aug','Sep','Oct','Nov','Dec'];

  String get createdAtFormatted {
    if (createdAt == null) return '—';
    return '${_months[createdAt!.month - 1]} ${createdAt!.day}, ${createdAt!.year}';
  }
}
