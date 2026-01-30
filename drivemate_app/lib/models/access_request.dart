import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequest {
  AccessRequest({
    required this.id,
    required this.schoolId,
    required this.ownerId,
    required this.instructorId,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String schoolId;
  final String ownerId;
  final String instructorId;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'ownerId': ownerId,
      'instructorId': instructorId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static AccessRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AccessRequest(
      id: doc.id,
      schoolId: (data['schoolId'] ?? '') as String,
      ownerId: (data['ownerId'] ?? '') as String,
      instructorId: (data['instructorId'] ?? '') as String,
      status: (data['status'] ?? 'pending') as String,
      createdAt: _toDateTime(data['createdAt']),
      respondedAt: _toDateTime(data['respondedAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
