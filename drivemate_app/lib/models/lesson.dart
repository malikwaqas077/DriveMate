import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  Lesson({
    required this.id,
    required this.instructorId,
    required this.studentId,
    this.schoolId,
    required this.startAt,
    required this.durationHours,
    this.lessonType = 'lesson',
    this.status = 'scheduled',
    this.notes,
    this.studentReflection,
  });

  final String id;
  final String instructorId;
  final String studentId;
  final String? schoolId;
  final DateTime startAt;
  final double durationHours;
  final String lessonType;
  final String status; // 'scheduled', 'completed', 'cancelled'
  final String? notes;
  final String? studentReflection;

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'studentId': studentId,
      'schoolId': schoolId,
      'startAt': Timestamp.fromDate(startAt),
      'durationHours': durationHours,
      'lessonType': lessonType,
      'status': status,
      'notes': notes,
      if (studentReflection != null) 'studentReflection': studentReflection,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Lesson fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      schoolId: data['schoolId'] as String?,
      startAt: _toDateTime(data['startAt']) ?? DateTime.now(),
      durationHours: _toDouble(data['durationHours']),
      lessonType: (data['lessonType'] ?? 'lesson') as String,
      status: (data['status'] ?? 'scheduled') as String,
      notes: data['notes'] as String?,
      studentReflection: data['studentReflection'] as String?,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
