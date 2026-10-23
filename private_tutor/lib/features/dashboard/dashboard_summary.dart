import 'package:intl/intl.dart';

import '../../data/models/fee_record.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.amountDue,
    required this.amountReceived,
    required this.selectedMonthOutstanding,
    required this.earlierOutstanding,
    required this.allOutstanding,
    required this.paidCount,
    required this.recordCount,
  });

  final int amountDue;
  final int amountReceived;
  final int selectedMonthOutstanding;
  final int earlierOutstanding;
  final int allOutstanding;
  final int paidCount;
  final int recordCount;

  double get receivedProgress => amountDue <= 0
      ? 0
      : (amountReceived / amountDue).clamp(0.0, 1.0).toDouble();

  factory DashboardSummary.fromRecords(
    Iterable<FeeRecord> records,
    DateTime month,
  ) {
    final monthKey = DateFormat('yyyy-MM').format(month);
    final all = records.toList(growable: false);
    final selected = all.where((record) => record.month == monthKey);
    final selectedList = selected.toList(growable: false);
    final earlier = all.where((record) => record.month.compareTo(monthKey) < 0);

    return DashboardSummary(
      amountDue: selectedList.fold(0, (sum, record) => sum + record.amountDue),
      amountReceived: selectedList.fold(
        0,
        (sum, record) => sum + record.amountPaid,
      ),
      selectedMonthOutstanding: selectedList.fold(
        0,
        (sum, record) => sum + record.remaining,
      ),
      earlierOutstanding: earlier.fold(
        0,
        (sum, record) => sum + record.remaining,
      ),
      allOutstanding: all.fold(0, (sum, record) => sum + record.remaining),
      paidCount: selectedList.where((record) => record.status == 'paid').length,
      recordCount: selectedList.length,
    );
  }
}
