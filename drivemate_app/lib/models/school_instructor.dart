import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolInstructor {
  SchoolInstructor({
    required this.id,
    required this.schoolId,
    required this.instructorId,
    required this.feeAmount,
    required this.feeFrequency,
    required this.active,
    this.createdAt,
  });

  final String id;
  final String schoolId;
  final String instructorId;
  final double feeAmount;
  final String feeFrequency;
  final bool active;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'instructorId': instructorId,
      'feeAmount': feeAmount,
      'feeFrequency': feeFrequency,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static SchoolInstructor fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SchoolInstructor(
      id: doc.id,
      schoolId: (data['schoolId'] ?? '') as String,
      instructorId: (data['instructorId'] ?? '') as String,
      feeAmount: _toDouble(data['feeAmount']),
      feeFrequency: (data['feeFrequency'] ?? 'week') as String,
      active: (data['active'] ?? true) as bool,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
