import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

abstract interface class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({firebase.FirebaseAuth? auth})
    : _auth = auth ?? firebase.FirebaseAuth.instance;

  final firebase.FirebaseAuth _auth;

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : AuthUser(id: user.uid, email: user.email),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _messageFor(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'user-disabled' => 'This tutor account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    'network-request-failed' => 'Check your internet connection and try again.',
    _ => 'Unable to sign in. Please try again.',
  };
}

class UnavailableAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw AuthFailure(
      'Firebase is not configured for this app yet. Add the Firebase project '
      'configuration to enable sign-in.',
    );
  }

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('Override authRepositoryProvider in main.'),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);
