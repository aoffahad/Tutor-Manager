import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class FeePayment {
  const FeePayment({this.id = '', required this.amount, required this.paidAt});

  final String id;
  final int amount;
  final DateTime? paidAt;

  factory FeePayment.fromMap(Map<String, dynamic> data) {
    final timestamp = data['paidAt'];
    return FeePayment(
      id: data['id'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paidAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class FeeRecord {
  const FeeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.month,
    required this.amountDue,
    required this.amountPaid,
    this.payments = const [],
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String month;
  final int amountDue;
  final int amountPaid;
  final List<FeePayment> payments;
  final DateTime? updatedAt;

  int get remaining => math.max(0, amountDue - amountPaid).toInt();

  String get status {
    if (remaining == 0) return 'paid';
    if (amountPaid > 0) return 'partial';
    return 'due';
  }

  factory FeeRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawPayments = data['payments'];
    final updatedAt = data['updatedAt'];
    return FeeRecord(
      id: document.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      month: data['month'] as String? ?? '',
      amountDue: (data['amountDue'] as num?)?.toInt() ?? 0,
      amountPaid: (data['amountPaid'] as num?)?.toInt() ?? 0,
      payments: rawPayments is Iterable
          ? rawPayments
                .whereType<Map>()
                .map(
                  (payment) =>
                      FeePayment.fromMap(Map<String, dynamic>.from(payment)),
                )
                .toList(growable: false)
          : const [],
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
