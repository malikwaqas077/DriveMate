import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  School({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String status;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static School fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return School(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      ownerId: (data['ownerId'] ?? '') as String,
      status: (data['status'] ?? 'active') as String,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
