import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/fee_record.dart';
import '../../data/repositories/fee_repository.dart';
import '../../data/repositories/repository_providers.dart';

Future<void> showRecordPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  required String studentName,
  required FeeRecord record,
}) async {
  final receipt = await showModalBottomSheet<PaymentReceipt>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        RecordPaymentSheet(studentName: studentName, record: record),
  );
  if (receipt == null || !context.mounted) return;

  final user = ref.read(authStateProvider).value;
  if (user == null) return;
  final repository = ref.read(feeRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text('${formatTaka(receipt.amount)} payment recorded.'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => unawaited(
          _undoPayment(
            messenger: messenger,
            repository: repository,
            uid: user.id,
            receipt: receipt,
          ),
        ),
      ),
    ),
  );
}

Future<void> _undoPayment({
  required ScaffoldMessengerState messenger,
  required FeeRepository repository,
  required String uid,
  required PaymentReceipt receipt,
}) async {
  try {
    await repository.undoPayment(uid: uid, receipt: receipt);
    messenger.showSnackBar(const SnackBar(content: Text('Payment undone.')));
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not undo this payment.')),
    );
  }
}

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({
    required this.studentName,
    required this.record,
    super.key,
  });

  final String studentName;
  final FeeRecord record;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: '${widget.record.remaining}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      setState(() => _saveError = 'Your session has expired. Sign in again.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final receipt = await ref
          .read(feeRepositoryProvider)
          .recordPayment(
            uid: user.id,
            feeRecordId: widget.record.id,
            amount: int.parse(_amountController.text),
          );
      if (mounted) {
        setState(() => _saving = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(receipt);
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saveError =
              'Could not record payment. The balance may have changed; please check and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthName(widget.record.month);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record payment',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.studentName} · $month · ${formatTaka(widget.record.remaining)} due',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              Text(
                'Amount received (Taka)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                autofocus: true,
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: 'Enter amount'),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount < 1) {
                    return 'Enter an amount greater than 0.';
                  }
                  if (amount > widget.record.remaining) {
                    return 'Amount cannot be more than ${formatTaka(widget.record.remaining)}.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Pay less than ${formatTaka(widget.record.remaining)} and the rest stays due.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _saveError!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _confirmPayment,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirm'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
