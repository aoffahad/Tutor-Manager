import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/student.dart';
import '../../data/repositories/repository_providers.dart';

const _weekDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({this.student, super.key});

  final Student? student;

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _feeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _guardianPhoneController;
  late final TextEditingController _addressController;
  late final Set<String> _selectedDays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _timeError;
  String? _saveError;
  String? _createdStudentId;
  bool _saving = false;
  bool _archiving = false;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _nameController = TextEditingController(text: student?.name ?? '');
    _feeController = TextEditingController(
      text: student == null ? '' : '${student.monthlyFee}',
    );
    _phoneController = TextEditingController(text: student?.phone ?? '');
    _guardianPhoneController = TextEditingController(
      text: student?.guardianPhone ?? '',
    );
    _addressController = TextEditingController(text: student?.address ?? '');
    _selectedDays = {...?student?.days};
    _startTime = _parseTime(student?.startTime);
    _endTime = _parseTime(student?.endTime);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _phoneController.dispose();
    _guardianPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeValue(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          (start ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
      _timeError = null;
    });
  }

  bool _validateSchedule() {
    String? error;
    if ((_startTime == null) != (_endTime == null)) {
      error = 'Select both From and To times, or leave both blank.';
    } else if (_startTime != null && _endTime != null) {
      final start = _startTime!.hour * 60 + _startTime!.minute;
      final end = _endTime!.hour * 60 + _endTime!.minute;
      if (end <= start) error = 'End time must be after start time.';
    }
    setState(() => _timeError = error);
    return error == null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    final scheduleValid = _validateSchedule();
    if (!valid || _selectedDays.isEmpty || !scheduleValid) {
      setState(() {});
      return;
    }

    final auth = ref.read(authStateProvider);
    final user = auth.value;
    if (user == null) {
      setState(() => _saveError = 'Your session has expired. Sign in again.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final monthKey = DateFormat('yyyy-MM').format(month);
      final existing = widget.student;
      final student = Student(
        id: existing?.id ?? _createdStudentId ?? '',
        name: _nameController.text.trim(),
        monthlyFee: int.parse(_feeController.text),
        phone: _phoneController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        address: _addressController.text.trim(),
        days: _weekDays.where(_selectedDays.contains).toList(growable: false),
        startTime: _timeValue(_startTime),
        endTime: _timeValue(_endTime),
        isActive: existing?.isActive ?? true,
        joinedMonth: existing?.joinedMonth ?? monthKey,
        createdAt: existing?.createdAt,
      );

      final students = ref.read(studentRepositoryProvider);
      final fees = ref.read(feeRepositoryProvider);
      if (existing != null) {
        // Fill any missing historical months using the old fee before changing it.
        await fees.ensureRecordsThroughMonth(user.id, existing, month);
        await students.updateStudent(user.id, student);
      } else {
        if (_createdStudentId == null) {
          _createdStudentId = await students.createStudent(user.id, student);
        } else {
          await students.updateStudent(
            user.id,
            Student(
              id: _createdStudentId!,
              name: student.name,
              monthlyFee: student.monthlyFee,
              phone: student.phone,
              guardianPhone: student.guardianPhone,
              address: student.address,
              days: student.days,
              startTime: student.startTime,
              endTime: student.endTime,
              isActive: true,
              joinedMonth: monthKey,
            ),
          );
        }
        await fees.ensureRecordsThroughMonth(
          user.id,
          Student(
            id: _createdStudentId!,
            name: student.name,
            monthlyFee: student.monthlyFee,
            phone: student.phone,
            guardianPhone: student.guardianPhone,
            address: student.address,
            days: student.days,
            startTime: student.startTime,
            endTime: student.endTime,
            isActive: true,
            joinedMonth: monthKey,
          ),
          month,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Student updated.' : 'Student saved.'),
        ),
      );
      _navigateBack();
    } on Object {
      if (mounted) {
        setState(() {
          _saveError = _createdStudentId == null
              ? 'Could not save student. Please try again.'
              : 'Student saved, but fee records could not be created. Try saving again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveStudent() async {
    final student = widget.student;
    if (student == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive student?'),
        content: Text(
          '${student.name} will no longer receive new monthly fee records. Existing dues will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _archiving = true);
    try {
      await ref
          .read(feeRepositoryProvider)
          .ensureRecordsThroughMonth(user.id, student, DateTime.now());
      await ref
          .read(studentRepositoryProvider)
          .archiveStudent(user.id, student.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student archived. Existing dues are unchanged.'),
        ),
      );
      _navigateBack();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not archive student. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/students');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _archiving;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _navigateBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(_isEditing ? 'Edit student' : 'Add student'),
        actions: [
          if (widget.student?.isActive == true)
            TextButton.icon(
              onPressed: busy ? null : _archiveStudent,
              icon: const Icon(
                Icons.archive_outlined,
                color: Color(0xFFB91C1C),
              ),
              label: const Text(
                'Archive',
                style: TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _fieldLabel('Student name'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Enter student name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Student name is required.'
                  : null,
            ),
            const SizedBox(height: 18),
            _fieldLabel('Fees (Taka)'),
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Enter monthly fee'),
              validator: (value) {
                final fee = int.tryParse(value ?? '');
                return fee == null || fee <= 0
                    ? 'Fee must be greater than 0.'
                    : null;
              },
            ),
            const SizedBox(height: 18),
            _fieldLabel('Phone number'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Enter phone number'),
            ),
            const SizedBox(height: 18),
            _fieldLabel("Guardian's phone no."),
            TextFormField(
              controller: _guardianPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter guardian phone number',
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Address'),
            TextFormField(
              controller: _addressController,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Enter address',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Days'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekDays.map(_daySelector).toList(growable: false),
            ),
            if (_selectedDays.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Select at least one day.',
                  style: TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _timeSelector('From', _startTime, true)),
                const SizedBox(width: 14),
                Expanded(child: _timeSelector('To', _endTime, false)),
              ],
            ),
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _timeError!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            if (_isEditing && widget.student?.joinedMonth.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  'Fee changes apply from next month. Joining month: ${widget.student!.joinedMonth}.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
            if (_saveError != null) ...[
              const SizedBox(height: 16),
              Text(
                _saveError!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: busy ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save changes' : 'Save student'),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
  );

  Widget _daySelector(String day) {
    final selected = _selectedDays.contains(day);
    return Semantics(
      label: day,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() {
          if (selected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 78, minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFCCFBF1) : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(day, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeSelector(String label, TimeOfDay? time, bool start) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: () => _selectTime(start: start),
          icon: const Icon(Icons.access_time_rounded),
          label: Text(time?.format(context) ?? 'Select time'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    ],
  );
}
