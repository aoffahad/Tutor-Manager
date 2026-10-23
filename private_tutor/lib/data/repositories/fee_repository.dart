import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fee_record.dart';
import '../models/student.dart';
import 'fee_ledger.dart';

abstract interface class FeeRepository {
  Stream<List<FeeRecord>> watchFeeRecords(String uid);

  Future<PaymentReceipt> recordPayment({
    required String uid,
    required String feeRecordId,
    required int amount,
  });

  Future<void> undoPayment({
    required String uid,
    required PaymentReceipt receipt,
  });

  Future<void> ensureRecordsThroughMonth(
    String uid,
    Student student,
    DateTime throughMonth,
  );
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.paymentId,
    required this.feeRecordId,
    required this.amount,
  });

  final String paymentId;
  final String feeRecordId;
  final int amount;
}

class FirestoreFeeRepository implements FeeRepository {
  const FirestoreFeeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<FeeRecord>> watchFeeRecords(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('feeRecords')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(FeeRecord.fromFirestore).toList(growable: false),
      );

  CollectionReference<Map<String, dynamic>> _records(String uid) =>
      _firestore.collection('users').doc(uid).collection('feeRecords');

  @override
  Future<PaymentReceipt> recordPayment({
    required String uid,
    required String feeRecordId,
    required int amount,
  }) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final records = _records(uid);
    final reference = records.doc(feeRecordId);
    final paymentId = records.doc().id;
    final paidAt = Timestamp.now();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Fee record no longer exists.');
      final data = snapshot.data()!;
      final balance = FeeBalance(
        amountDue: (data['amountDue'] as num?)?.toInt() ?? 0,
        amountPaid: (data['amountPaid'] as num?)?.toInt() ?? 0,
      );
      final nextBalance = balance.recordPayment(amount);

      final rawPayments = data['payments'];
      final payments = rawPayments is Iterable
          ? rawPayments
                .whereType<Map>()
                .map((payment) => Map<String, dynamic>.from(payment))
                .toList()
          : <Map<String, dynamic>>[];
      payments.add({'id': paymentId, 'amount': amount, 'paidAt': paidAt});
      transaction.update(reference, {
        'amountPaid': nextBalance.amountPaid,
        'status': nextBalance.status,
        'payments': payments,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return PaymentReceipt(
      paymentId: paymentId,
      feeRecordId: feeRecordId,
      amount: amount,
    );
  }

  @override
  Future<void> undoPayment({
    required String uid,
    required PaymentReceipt receipt,
  }) async {
    final reference = _records(uid).doc(receipt.feeRecordId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Fee record no longer exists.');
      final data = snapshot.data()!;
      final balance = FeeBalance(
        amountDue: (data['amountDue'] as num?)?.toInt() ?? 0,
        amountPaid: (data['amountPaid'] as num?)?.toInt() ?? 0,
      );
      final rawPayments = data['payments'];
      final payments = rawPayments is Iterable
          ? rawPayments
                .whereType<Map>()
                .map((payment) => Map<String, dynamic>.from(payment))
                .toList()
          : <Map<String, dynamic>>[];
      final paymentIndex = payments.indexWhere(
        (payment) => payment['id'] == receipt.paymentId,
      );
      if (paymentIndex < 0) throw StateError('Payment was already undone.');
      if (paymentIndex != payments.length - 1) {
        throw StateError('Only the latest payment can be undone.');
      }

      final paymentAmount =
          (payments[paymentIndex]['amount'] as num?)?.toInt() ?? 0;
      final nextBalance = balance.undoPayment(paymentAmount);
      payments.removeAt(paymentIndex);
      transaction.update(reference, {
        'amountPaid': nextBalance.amountPaid,
        'status': nextBalance.status,
        'payments': payments,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> ensureRecordsThroughMonth(
    String uid,
    Student student,
    DateTime throughMonth,
  ) async {
    if (!student.isActive) return;

    final records = _firestore
        .collection('users')
        .doc(uid)
        .collection('feeRecords');
    for (final feeMonth in feeMonthsFromJoinDate(
      student: student,
      throughMonth: throughMonth,
    )) {
      final reference = records.doc(feeMonth.documentId);

      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) return;
        transaction.set(reference, {
          'studentId': student.id,
          'studentName': student.name,
          'month': feeMonth.month,
          'amountDue': feeMonth.amountDue,
          'amountPaid': 0,
          'status': 'due',
          'payments': <Map<String, dynamic>>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }
}
