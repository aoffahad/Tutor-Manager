import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/fee_record.dart';
import '../models/student.dart';

class FeeBalance {
  const FeeBalance({required this.amountDue, required this.amountPaid});

  final int amountDue;
  final int amountPaid;

  int get remaining => math.max(0, amountDue - amountPaid).toInt();

  String get status {
    if (remaining == 0) return 'paid';
    if (amountPaid > 0) return 'partial';
    return 'due';
  }

  FeeBalance recordPayment(int amount) {
    if (amount < 1 || amount > remaining) {
      throw ArgumentError.value(amount, 'amount', 'Outside remaining balance');
    }
    return FeeBalance(amountDue: amountDue, amountPaid: amountPaid + amount);
  }

  FeeBalance undoPayment(int amount) {
    if (amount < 1 || amount > amountPaid) {
      throw ArgumentError.value(amount, 'amount', 'Outside paid balance');
    }
    return FeeBalance(amountDue: amountDue, amountPaid: amountPaid - amount);
  }
}

class FeeMonth {
  const FeeMonth({
    required this.month,
    required this.documentId,
    required this.amountDue,
  });

  final String month;
  final String documentId;
  final int amountDue;
}

List<FeeMonth> feeMonthsFromJoinDate({
  required Student student,
  required DateTime throughMonth,
}) {
  final through = DateTime(throughMonth.year, throughMonth.month);
  DateTime joined;
  try {
    joined = DateFormat('yyyy-MM').parseStrict(student.joinedMonth);
  } on FormatException {
    joined = through;
  }
  var month = DateTime(joined.year, joined.month);
  final months = <FeeMonth>[];
  while (!month.isAfter(through)) {
    final monthKey = DateFormat('yyyy-MM').format(month);
    months.add(
      FeeMonth(
        month: monthKey,
        documentId: '${student.id}_${DateFormat('yyyyMM').format(month)}',
        amountDue: student.monthlyFee,
      ),
    );
    month = DateTime(month.year, month.month + 1);
  }
  return months;
}

List<FeeMonth> missingFeeMonths(
  Iterable<FeeMonth> months,
  Set<String> existingDocumentIds,
) => months
    .where((month) => !existingDocumentIds.contains(month.documentId))
    .toList(growable: false);

List<FeeRecord> unpaidFeeRecords(Iterable<FeeRecord> records) => records
    .where((record) => record.remaining > 0)
    .toList(growable: false);
