import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/fee_record.dart';
import '../../data/models/student.dart';
import '../../data/repositories/repository_providers.dart';
import '../dashboard/dashboard_month_provider.dart';
import '../dues/record_payment_sheet.dart';

enum _StudentFilter { all, due, paid }

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({this.initialFilter = 'all', super.key});

  final String initialFilter;

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  _StudentFilter _filter = _StudentFilter.all;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _filter = _filterFrom(widget.initialFilter);
  }

  @override
  void didUpdateWidget(covariant StudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() => _filter = _filterFrom(widget.initialFilter));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  _StudentFilter _filterFrom(String value) => switch (value.toLowerCase()) {
    'due' => _StudentFilter.due,
    'paid' => _StudentFilter.paid,
    _ => _StudentFilter.all,
  };

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsStreamProvider);
    final feeRecordsAsync = ref.watch(feeRecordsStreamProvider);
    final month = ref.watch(dashboardMonthProvider);
    final monthKey = DateFormat('yyyy-MM').format(month);
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 2),
                  studentsAsync.when(
                    loading: () => const Text('All students'),
                    error: (error, stack) => const Text('All students'),
                    data: (students) => Text(
                      'All students (${students.where((student) => student.isActive).length})',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _search = value.trim()),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search students',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == _StudentFilter.all,
                        onSelected: () =>
                            setState(() => _filter = _StudentFilter.all),
                      ),
                      _FilterChip(
                        label: 'Due',
                        selected: _filter == _StudentFilter.due,
                        onSelected: () =>
                            setState(() => _filter = _StudentFilter.due),
                      ),
                      _FilterChip(
                        label: 'Paid',
                        selected: _filter == _StudentFilter.paid,
                        onSelected: () =>
                            setState(() => _filter = _StudentFilter.paid),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildStudentList(
                context,
                studentsAsync,
                feeRecordsAsync,
                monthKey,
                monthLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(
    BuildContext context,
    AsyncValue<List<Student>> studentsAsync,
    AsyncValue<List<FeeRecord>> feeRecordsAsync,
    String monthKey,
    String monthLabel,
  ) {
    if (studentsAsync.isLoading || feeRecordsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (studentsAsync.hasError || feeRecordsAsync.hasError) {
      return _StudentsMessage(
        icon: Icons.cloud_off_rounded,
        message: 'Could not load student fee details.',
        action: TextButton(
          onPressed: () {
            ref.invalidate(studentsStreamProvider);
            ref.invalidate(feeRecordsStreamProvider);
          },
          child: const Text('Try again'),
        ),
      );
    }

    final active = (studentsAsync.value ?? const <Student>[])
        .where((student) => student.isActive)
        .toList(growable: false);
    final records = feeRecordsAsync.value ?? const <FeeRecord>[];
    final filtered =
        active.where((student) {
          if (_search.isNotEmpty &&
              !student.name.toLowerCase().contains(_search.toLowerCase())) {
            return false;
          }
          final current = _currentRecord(records, student.id, monthKey);
          final status = _statusFor(current);
          return switch (_filter) {
            _StudentFilter.all => true,
            _StudentFilter.due => status != 'paid',
            _StudentFilter.paid => status == 'paid',
          };
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    if (filtered.isEmpty) {
      final message = active.isEmpty
          ? 'No students yet. Add your first student to get started.'
          : 'No students match your search and filter.';
      return _StudentsMessage(
        icon: Icons.people_outline_rounded,
        message: message,
        action: active.isEmpty
            ? FilledButton.icon(
                onPressed: () => context.go('/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add student'),
              )
            : const SizedBox.shrink(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentsStreamProvider);
        ref.invalidate(feeRecordsStreamProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final student = filtered[index];
          final current = _currentRecord(records, student.id, monthKey);
          final studentRecords = records
              .where((record) => record.studentId == student.id)
              .toList(growable: false);
          return _StudentCard(
            student: student,
            currentRecord: current,
            records: studentRecords,
            monthLabel: monthLabel,
          );
        },
      ),
    );
  }
}

FeeRecord? _currentRecord(
  List<FeeRecord> records,
  String studentId,
  String month,
) {
  for (final record in records) {
    if (record.studentId == studentId && record.month == month) return record;
  }
  return null;
}

String _statusFor(FeeRecord? record) => record?.status ?? 'due';

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    labelStyle: TextStyle(
      color: selected ? Colors.white : AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
    selectedColor: AppColors.primary,
    backgroundColor: AppColors.surface,
    side: BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({
    required this.student,
    required this.currentRecord,
    required this.records,
    required this.monthLabel,
  });

  final Student student;
  final FeeRecord? currentRecord;
  final List<FeeRecord> records;
  final String monthLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _statusFor(currentRecord);
    final paid = status == 'paid';
    final border = paid ? const Color(0xB316A34A) : const Color(0xB3DC2626);
    final schedule = [
      student.days.join(' '),
      _formatScheduleTime(student.startTime, student.endTime),
    ].where((part) => part.isNotEmpty).join(' · ');
    final unpaidRecords =
        records.where((record) => record.remaining > 0).toList()
          ..sort((a, b) => b.month.compareTo(a.month));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          key: PageStorageKey<String>('student-${student.id}'),
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: status),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              schedule.isEmpty ? 'Schedule not set' : schedule,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          children: [
            const Divider(height: 12),
            _StudentDetails(student: student),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/add', extra: student),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit student'),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Unpaid months',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            if (unpaidRecords.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No unpaid months.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              )
            else
              ...unpaidRecords.map(
                (record) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(_monthName(record.month))),
                      Text(
                        formatTaka(record.remaining),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _ContactActions(student: student),
            if (currentRecord != null && currentRecord!.remaining > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => showRecordPaymentSheet(
                    context,
                    ref,
                    studentName: student.name,
                    record: currentRecord!,
                  ),
                  child: Text('Mark $monthLabel as received'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final label = switch (status) {
      'paid' => 'Paid',
      'partial' => 'Part paid',
      _ => 'Due',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: paid ? const Color(0xFF166534) : const Color(0xFFB91C1C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentDetails extends StatelessWidget {
  const _StudentDetails({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Detail(
              label: 'Monthly fee',
              value: formatTaka(student.monthlyFee),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _Detail(label: 'Phone', value: _orDash(student.phone)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Detail(
              label: 'Guardian',
              value: _orDash(student.guardianPhone),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _Detail(label: 'Address', value: _orDash(student.address)),
          ),
        ],
      ),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 1),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ContactRow(label: 'Student', number: student.phone),
      const SizedBox(height: 4),
      _ContactRow(label: 'Guardian', number: student.guardianPhone),
    ],
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.label, required this.number});

  final String label;
  final String number;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('$label · ${_orDash(number)}')),
      IconButton(
        tooltip: 'Call $label',
        onPressed: number.trim().isEmpty
            ? null
            : () => _launchContact(context, 'tel', number),
        icon: const Icon(Icons.call_outlined),
      ),
      IconButton(
        tooltip: 'SMS $label',
        onPressed: number.trim().isEmpty
            ? null
            : () => _launchContact(context, 'sms', number),
        icon: const Icon(Icons.sms_outlined),
      ),
    ],
  );
}

Future<void> _launchContact(
  BuildContext context,
  String scheme,
  String number,
) async {
  final uri = Uri(scheme: scheme, path: number.trim());
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $scheme for this number.')),
      );
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $scheme for this number.')),
      );
    }
  }
}

String _monthName(String month) {
  try {
    return DateFormat(
      'MMMM yyyy',
    ).format(DateFormat('yyyy-MM').parseStrict(month));
  } on FormatException {
    return month;
  }
}

String _orDash(String value) => value.trim().isEmpty ? '—' : value;

String _formatScheduleTime(String startTime, String endTime) {
  if (startTime.isEmpty || endTime.isEmpty) return '';
  final start = _toTimeOfDay(startTime);
  final end = _toTimeOfDay(endTime);
  if (start == null || end == null) return '';
  final startTimeLabel = _formatTime(start);
  final endTimeLabel = _formatTime(end);
  final startSuffix = start.period == DayPeriod.am ? 'AM' : 'PM';
  final endSuffix = end.period == DayPeriod.am ? 'AM' : 'PM';
  return startSuffix == endSuffix
      ? '$startTimeLabel–$endTimeLabel $endSuffix'
      : '$startTimeLabel $startSuffix–$endTimeLabel $endSuffix';
}

String _formatTime(TimeOfDay time) =>
    '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')}';

TimeOfDay? _toTimeOfDay(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

class _StudentsMessage extends StatelessWidget {
  const _StudentsMessage({
    required this.icon,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          action,
        ],
      ),
    ),
  );
}
