import 'package:cloud_firestore/cloud_firestore.dart';

class CancellationRequest {
  CancellationRequest({
    required this.id,
    required this.lessonId,
    required this.studentId,
    required this.instructorId,
    this.schoolId,
    required this.status,
    this.reason,
    required this.chargePercent,
    required this.hoursToDeduct,
    required this.createdAt,
    this.respondedAt,
    this.lessonStartAt,
  });

  final String id;
  final String lessonId;
  final String studentId;
  final String instructorId;
  final String? schoolId;
  final String status; // 'pending', 'approved', 'declined'
  final String? reason;
  final int chargePercent;
  final double hoursToDeduct;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? lessonStartAt; // For display purposes

  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'studentId': studentId,
      'instructorId': instructorId,
      'schoolId': schoolId,
      'status': status,
      if (reason != null) 'reason': reason,
      'chargePercent': chargePercent,
      'hoursToDeduct': hoursToDeduct,
      'createdAt': FieldValue.serverTimestamp(),
      if (lessonStartAt != null)
        'lessonStartAt': Timestamp.fromDate(lessonStartAt!),
    };
  }

  static CancellationRequest fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CancellationRequest(
      id: doc.id,
      lessonId: (data['lessonId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      instructorId: (data['instructorId'] ?? '') as String,
      schoolId: data['schoolId'] as String?,
      status: (data['status'] ?? 'pending') as String,
      reason: data['reason'] as String?,
      chargePercent: (data['chargePercent'] ?? 0) as int,
      hoursToDeduct: _toDouble(data['hoursToDeduct']),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      respondedAt: _toDateTime(data['respondedAt']),
      lessonStartAt: _toDateTime(data['lessonStartAt']),
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

  CancellationRequest copyWith({
    String? status,
    DateTime? respondedAt,
  }) {
    return CancellationRequest(
      id: id,
      lessonId: lessonId,
      studentId: studentId,
      instructorId: instructorId,
      schoolId: schoolId,
      status: status ?? this.status,
      reason: reason,
      chargePercent: chargePercent,
      hoursToDeduct: hoursToDeduct,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      lessonStartAt: lessonStartAt,
    );
  }
}
