import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/fee_record.dart';
import '../../data/models/student.dart';
import '../../data/repositories/repository_providers.dart';
import 'dashboard_month_provider.dart';
import 'dashboard_summary.dart';
import '../shared/month_selector.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _pickMonth(DateTime month) async {
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
  Widget build(BuildContext context) {
    final month = ref.watch(dashboardMonthProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final feesAsync = ref.watch(feeRecordsStreamProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(studentsStreamProvider);
            ref.invalidate(feeRecordsStreamProvider);
            await Future<void>.delayed(const Duration(milliseconds: 250));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tuition Manager',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dashboard',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('dashboard-sign-out'),
                    tooltip: 'Sign out',
                    onPressed: _signingOut ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              MonthSelector(
                month: month,
                onPrevious: () =>
                    ref.read(dashboardMonthProvider.notifier).moveBy(-1),
                onNext: () =>
                    ref.read(dashboardMonthProvider.notifier).moveBy(1),
                onPick: () => _pickMonth(month),
              ),
              const SizedBox(height: 18),
              if (studentsAsync.isLoading || feesAsync.isLoading)
                const _LoadingPanel()
              else if (studentsAsync.hasError || feesAsync.hasError)
                _ErrorPanel(
                  onRetry: () {
                    ref.invalidate(studentsStreamProvider);
                    ref.invalidate(feeRecordsStreamProvider);
                  },
                )
              else
                _buildDashboardContent(
                  context,
                  studentsAsync.value ?? const <Student>[],
                  feesAsync.value ?? const <FeeRecord>[],
                  monthLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    List<Student> students,
    List<FeeRecord> fees,
    String monthLabel,
  ) {
    final activeStudents = students.where((student) => student.isActive).length;
    final selectedMonth = ref.read(dashboardMonthProvider);
    final summary = DashboardSummary.fromRecords(fees, selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(monthLabel: monthLabel, summary: summary),
        if (activeStudents == 0) ...[
          const SizedBox(height: 14),
          const _EmptyStudentsNotice(),
        ] else if (summary.recordCount == 0) ...[
          const SizedBox(height: 14),
          _EmptyFeesNotice(monthLabel: monthLabel),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 14.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _DashboardTile(
                  width: width,
                  icon: Icons.people_alt_outlined,
                  label: 'Total students',
                  value: '$activeStudents',
                  hint: 'Tap to view all',
                  onTap: () => context.go('/students?filter=all'),
                ),
                _DashboardTile(
                  width: width,
                  icon: Icons.check_rounded,
                  label: 'Received',
                  value: formatTaka(summary.amountReceived),
                  hint: '$monthLabel · ${summary.paidCount} paid',
                  onTap: () => context.go('/received'),
                ),
                _DashboardTile(
                  width: width,
                  icon: Icons.schedule_rounded,
                  label: 'Due amount',
                  value: formatTaka(summary.allOutstanding),
                  hint:
                      '${DateFormat('MMM').format(selectedMonth)} ${formatTaka(summary.selectedMonthOutstanding)} · Earlier ${formatTaka(summary.earlierOutstanding)}',
                  iconBackground: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFB91C1C),
                  onTap: () => context.go('/dues'),
                ),
                _DashboardTile(
                  width: width,
                  icon: Icons.add_rounded,
                  label: 'New enrollment',
                  value: 'Add student',
                  hint: 'Opens the form',
                  highlighted: true,
                  onTap: () => context.go('/add'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.monthLabel, required this.summary});

  final String monthLabel;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$monthLabel fees',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatTaka(summary.amountDue),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: summary.receivedProgress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              [
                    Text('${formatTaka(summary.amountReceived)} received'),
                    Text('${formatTaka(summary.selectedMonthOutstanding)} due'),
                  ]
                  .map(
                    (text) => DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      child: text,
                    ),
                  )
                  .toList(),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(color: Color(0x66FFFFFF), height: 1),
        ),
        Text(
          'Earlier months due: ${formatTaka(summary.earlierOutstanding)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.highlighted = false,
    this.iconBackground = const Color(0xFFCCFBF1),
    this.iconColor = AppColors.primary,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;
  final bool highlighted;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: highlighted ? const Color(0xFFCCFBF1) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 196),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? AppColors.primary : AppColors.divider,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: highlighted ? AppColors.primary : iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? Colors.white : iconColor,
                  size: 29,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 88),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        const Text('Could not load dashboard data.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _EmptyStudentsNotice extends StatelessWidget {
  const _EmptyStudentsNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        const Icon(Icons.people_outline_rounded, color: AppColors.primary),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'No active students yet. Add your first student to get started.',
          ),
        ),
        TextButton(
          onPressed: () => context.go('/add'),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

class _EmptyFeesNotice extends StatelessWidget {
  const _EmptyFeesNotice({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Text(
      'No fee records for $monthLabel yet.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
    ),
  );
}
