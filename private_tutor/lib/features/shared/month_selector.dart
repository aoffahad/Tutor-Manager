import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    super.key,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _MonthButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              DateFormat('MMMM yyyy').format(month),
              style: const TextStyle(fontSize: 18),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      _MonthButton(icon: Icons.chevron_right_rounded, onTap: onNext),
    ],
  );
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.divider),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Icon(icon, size: 30),
    ),
  );
}
