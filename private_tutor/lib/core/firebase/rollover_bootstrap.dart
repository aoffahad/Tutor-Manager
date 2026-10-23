import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../../data/repositories/repository_providers.dart';

class RolloverBootstrap extends ConsumerStatefulWidget {
  const RolloverBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RolloverBootstrap> createState() => _RolloverBootstrapState();
}

class _RolloverBootstrapState extends ConsumerState<RolloverBootstrap>
    with WidgetsBindingObserver {
  String? _lastUid;
  bool _running = false;
  bool _rerunRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleRollover(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.value;
    if (user != null && user.id != _lastUid) {
      _lastUid = user.id;
      _scheduleRollover();
    } else if (user == null && !auth.isLoading) {
      _lastUid = null;
    }
    return widget.child;
  }

  void _scheduleRollover({bool force = false}) {
    if (!mounted) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    if (!force && _lastUid != user.id) return;
    unawaited(_runRollover(user.id));
  }

  Future<void> _runRollover(String uid) async {
    _running = true;
    try {
      final students = await ref
          .read(studentRepositoryProvider)
          .watchStudents(uid)
          .first;
      for (final student in students.where((student) => student.isActive)) {
        await ref
            .read(feeRepositoryProvider)
            .ensureRecordsThroughMonth(uid, student, DateTime.now());
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tuition manager rollover',
          context: ErrorDescription('while creating missing monthly fee records'),
        ),
      );
    } finally {
      _running = false;
      if (_rerunRequested && mounted) {
        _rerunRequested = false;
        _scheduleRollover(force: true);
      }
    }
  }
}
