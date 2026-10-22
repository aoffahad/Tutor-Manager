import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_tutor/core/auth/auth_repository.dart';
import 'package:private_tutor/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-out tutor sees login and validation is inline', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository);

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(repository.signInCalls, 0);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repository.signInCalls, 0);
    await repository.dispose();
  });

  testWidgets('authentication error appears inline', (tester) async {
    final repository = _FakeAuthRepository()
      ..signInFailure = const AuthFailure('Email or password is incorrect.');
    await _pumpApp(tester, repository);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'tutor@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'wrong-pass',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byKey(const Key('login-auth-error')), findsOneWidget);
    await repository.dispose();
  });

  testWidgets('login shows loading and redirects to Home on success', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()..signInGate = Completer<void>();
    await _pumpApp(tester, repository);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'tutor@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );

    repository.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await repository.dispose();
  });

  testWidgets('existing session opens Home and sign-out redirects to Login', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      initialUser: const AuthUser(id: 'tutor-1', email: 'tutor@example.com'),
    );
    await _pumpApp(tester, repository);

    expect(find.text('Dashboard'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-sign-out')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await repository.dispose();
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  _FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const TuitionManagerApp(),
    ),
  );
  // Auth initially emits loading. Pump a few frames for the stream/router
  // transition without waiting for the indeterminate loader to stop animating.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthUser? initialUser}) : _currentUser = initialUser;

  AuthUser? _currentUser;
  final _changes = StreamController<AuthUser?>.broadcast(sync: true);
  int signInCalls = 0;
  AuthFailure? signInFailure;
  Completer<void>? signInGate;

  @override
  Stream<AuthUser?> get authStateChanges =>
      Stream<AuthUser?>.multi((controller) {
        controller.add(_currentUser);
        final subscription = _changes.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    if (signInGate != null) await signInGate!.future;
    if (signInFailure case final failure?) throw failure;
    _currentUser = AuthUser(id: 'tutor-1', email: email);
    _changes.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
