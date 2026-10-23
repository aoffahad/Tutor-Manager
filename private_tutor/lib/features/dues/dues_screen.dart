import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/fee_record.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/fee_ledger.dart';
import 'record_payment_sheet.dart';

class DuesScreen extends ConsumerWidget {
  const DuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(feeRecordsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dues')),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DuesMessage(
          message: 'Could not load dues.',
          action: TextButton(
            onPressed: () => ref.invalidate(feeRecordsStreamProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (records) {
          final unpaid =
              unpaidFeeRecords(records)
                ..sort((a, b) {
                  final monthOrder = b.month.compareTo(a.month);
                  return monthOrder != 0
                      ? monthOrder
                      : a.studentName.toLowerCase().compareTo(
                          b.studentName.toLowerCase(),
                        );
                });
          final total = unpaid.fold<int>(
            0,
            (sum, record) => sum + record.remaining,
          );
          if (unpaid.isEmpty) {
            return const _DuesMessage(message: 'No unpaid fees.');
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feeRecordsStreamProvider);
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'All unpaid months',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
                ),
                Text(
                  'Due ${formatTaka(total)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ..._monthGroups(unpaid).entries.map((entry) {
                  final monthTotal = entry.value.fold<int>(
                    0,
                    (sum, record) => sum + record.remaining,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _monthName(entry.key),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '${formatTaka(monthTotal)} · ${entry.value.length} students',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...entry.value.map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DueRecordTile(record: record),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

Map<String, List<FeeRecord>> _monthGroups(List<FeeRecord> records) {
  final groups = <String, List<FeeRecord>>{};
  for (final record in records) {
    groups.putIfAbsent(record.month, () => []).add(record);
  }
  return Map.fromEntries(
    groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
  );
}

class _DueRecordTile extends ConsumerWidget {
  const _DueRecordTile({required this.record});

  final FeeRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partial = record.status == 'partial';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xB3DC2626), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  partial
                      ? '${formatTaka(record.remaining)} left of ${formatTaka(record.amountDue)} · Part paid'
                      : formatTaka(record.remaining),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => showRecordPaymentSheet(
              context,
              ref,
              studentName: record.studentName,
              record: record,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, 48),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Received'),
          ),
        ],
      ),
    );
  }
}

class _DuesMessage extends StatelessWidget {
  const _DuesMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.credit_card_rounded,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

String _monthName(String value) {
  try {
    return DateFormat(
      'MMMM yyyy',
    ).format(DateFormat('yyyy-MM').parseStrict(value));
  } on FormatException {
    return value;
  }
}
