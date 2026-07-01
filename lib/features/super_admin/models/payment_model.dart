import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String date;
  final int amount;
  final String method;
  final String reference;

  const PaymentModel({
    required this.id,
    required this.date,
    required this.amount,
    this.method = 'bank_transfer',
    this.reference = '',
  });

  factory PaymentModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id:        doc.id,
      date:      d['date']      as String? ?? '',
      amount:    (d['amount'] as num?)?.toInt() ?? 0,
      method:    d['method']    as String? ?? 'bank_transfer',
      reference: d['reference'] as String? ?? '',
    );
  }

  String get methodLabel => switch (method) {
    'bank_transfer' => 'Bank Transfer',
    'mobile_money'  => 'Mobile Money',
    'cash'          => 'Cash',
    _               => method,
  };
}
