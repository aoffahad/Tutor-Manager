import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/fee_record.dart';
import '../../data/repositories/repository_providers.dart';
import '../dashboard/dashboard_month_provider.dart';
import '../shared/month_selector.dart';

class ReceivedScreen extends ConsumerWidget {
  const ReceivedScreen({super.key});

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select a month',
    );
    if (selected != null) {
      ref.read(dashboardMonthProvider.notifier).select(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final recordsAsync = ref.watch(feeRecordsStreamProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final monthKey = DateFormat('yyyy-MM').format(month);

    return Scaffold(
      appBar: AppBar(title: const Text('Received')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: MonthSelector(
                month: month,
                onPrevious: () =>
                    ref.read(dashboardMonthProvider.notifier).moveBy(-1),
                onNext: () =>
                    ref.read(dashboardMonthProvider.notifier).moveBy(1),
                onPick: () => _pickMonth(context, ref, month),
              ),
            ),
            Expanded(
              child: recordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load received payments.'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(feeRecordsStreamProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (records) {
                  final monthRecords = records
                      .where((record) => record.month == monthKey)
                      .toList(growable: false);
                  final total = monthRecords.fold<int>(
                    0,
                    (sum, record) => sum + record.amountPaid,
                  );
                  final payments = <_ReceivedPayment>[];
                  for (final record in monthRecords) {
                    for (final payment in record.payments) {
                      if (payment.amount > 0) {
                        payments.add(
                          _ReceivedPayment(
                            studentName: record.studentName,
                            payment: payment,
                          ),
                        );
                      }
                    }
                  }
                  payments.sort((a, b) {
                    final aDate = a.payment.paidAt;
                    final bDate = b.payment.paidAt;
                    if (aDate == null) return bDate == null ? 0 : 1;
                    if (bDate == null) return -1;
                    return bDate.compareTo(aDate);
                  });

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text(
                        '$monthLabel received',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatTaka(total),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      if (payments.isEmpty)
                        const _EmptyReceivedState()
                      else
                        ...payments.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PaymentTile(item: item),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedPayment {
  const _ReceivedPayment({required this.studentName, required this.payment});

  final String studentName;
  final FeePayment payment;
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item});

  final _ReceivedPayment item;

  @override
  Widget build(BuildContext context) {
    final paidAt = item.payment.paidAt;
    final dateLabel = paidAt == null
        ? 'Date unavailable'
        : DateFormat('d MMM yyyy · h:mm a').format(paidAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.studentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatTaka(item.payment.amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReceivedState extends StatelessWidget {
  const _EmptyReceivedState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 16),
    child: Column(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 46,
          color: AppColors.muted,
        ),
        const SizedBox(height: 12),
        Text(
          'No payments yet this month',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}
