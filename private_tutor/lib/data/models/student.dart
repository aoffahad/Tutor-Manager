import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.monthlyFee,
    required this.isActive,
    this.phone = '',
    this.guardianPhone = '',
    this.address = '',
    this.days = const [],
    this.startTime = '',
    this.endTime = '',
    this.joinedMonth = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final int monthlyFee;
  final String phone;
  final String guardianPhone;
  final String address;
  final List<String> days;
  final String startTime;
  final String endTime;
  final bool isActive;
  final String joinedMonth;
  final DateTime? createdAt;

  factory Student.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawDays = data['days'];
    final timestamp = data['createdAt'];
    return Student(
      id: document.id,
      name: data['name'] as String? ?? '',
      monthlyFee: (data['monthlyFee'] as num?)?.toInt() ?? 0,
      phone: data['phone'] as String? ?? '',
      guardianPhone: data['guardianPhone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      days: rawDays is Iterable
          ? rawDays.map((day) => day.toString()).toList(growable: false)
          : const [],
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      joinedMonth: data['joinedMonth'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
