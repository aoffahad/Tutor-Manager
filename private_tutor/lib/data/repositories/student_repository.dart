import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student.dart';

abstract interface class StudentRepository {
  Stream<List<Student>> watchStudents(String uid);

  Future<String> createStudent(String uid, Student student);

  Future<void> updateStudent(String uid, Student student);

  Future<void> archiveStudent(String uid, String studentId);
}

class FirestoreStudentRepository implements StudentRepository {
  const FirestoreStudentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Student>> watchStudents(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('students')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(Student.fromFirestore).toList(growable: false),
      );

  CollectionReference<Map<String, dynamic>> _students(String uid) =>
      _firestore.collection('users').doc(uid).collection('students');

  Map<String, dynamic> _editableFields(Student student) => {
    'name': student.name,
    'monthlyFee': student.monthlyFee,
    'phone': student.phone,
    'guardianPhone': student.guardianPhone,
    'address': student.address,
    'days': student.days,
    'startTime': student.startTime,
    'endTime': student.endTime,
    'isActive': student.isActive,
    'joinedMonth': student.joinedMonth,
  };

  @override
  Future<String> createStudent(String uid, Student student) async {
    final document = _students(uid).doc();
    await document.set({
      ..._editableFields(student),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  @override
  Future<void> updateStudent(String uid, Student student) =>
      _students(uid).doc(student.id).update(_editableFields(student));

  @override
  Future<void> archiveStudent(String uid, String studentId) =>
      _students(uid).doc(studentId).update({'isActive': false});
}
