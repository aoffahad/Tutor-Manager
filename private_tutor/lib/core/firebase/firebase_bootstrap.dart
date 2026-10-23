import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_repository.dart';

abstract final class FirebaseBootstrap {
  static Future<AuthRepository> createAuthRepository() async {
    try {
      if (Firebase.apps.isEmpty) {
        // Replace with Firebase.initializeApp(options: ...)
        // when FlutterFire project options are generated.
        await Firebase.initializeApp();
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      return FirebaseAuthRepository();
    } on Object {
      return UnavailableAuthRepository();
    }
  }
}
