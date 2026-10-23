import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../models/fee_record.dart';
import '../models/student.dart';
import 'fee_repository.dart';
import 'student_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => FirestoreStudentRepository(ref.watch(firestoreProvider)),
);

final feeRepositoryProvider = Provider<FeeRepository>(
  (ref) => FirestoreFeeRepository(ref.watch(firestoreProvider)),
);

final studentsStreamProvider = StreamProvider.autoDispose<List<Student>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth is! AsyncData<AuthUser?> || auth.value == null) {
    return Stream.value(const <Student>[]);
  }
  return ref.watch(studentRepositoryProvider).watchStudents(auth.value!.id);
});

final feeRecordsStreamProvider = StreamProvider.autoDispose<List<FeeRecord>>((
  ref,
) {
  final auth = ref.watch(authStateProvider);
  if (auth is! AsyncData<AuthUser?> || auth.value == null) {
    return Stream.value(const <FeeRecord>[]);
  }
  return ref.watch(feeRepositoryProvider).watchFeeRecords(auth.value!.id);
});
