import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  Student({
    required this.id,
    required this.instructorId,
    required this.name,
    this.schoolId,
    this.hourlyRate,
    required this.balanceHours,
    required this.status,
    this.email,
    this.phone,
    this.licenseNumber,
    this.address,
    this.createdAt,
  });

  final String id;
  final String instructorId;
  final String name;
  final String? schoolId;
  final String? email;
  final String? phone;
  final String? licenseNumber;
  final String? address;
  final double? hourlyRate;
  final double balanceHours;
  final String status;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'name': name,
      'schoolId': schoolId,
      'email': email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'address': address,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      'balanceHours': balanceHours,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Student fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Student(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      schoolId: data['schoolId'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
      address: data['address'] as String?,
      hourlyRate: _toNullableDouble(data['hourlyRate']),
      balanceHours: _toDouble(data['balanceHours']),
      status: (data['status'] ?? 'active') as String,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  static double? _toNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return null;
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
