import 'package:cloud_firestore/cloud_firestore.dart';

class Terms {
  Terms({
    required this.instructorId,
    required this.text,
    required this.version,
    this.updatedAt,
  });

  final String instructorId;
  final String text;
  final int version;
  final DateTime? updatedAt;

  static Terms fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Terms(
      instructorId: doc.id,
      text: (data['text'] ?? '') as String,
      version: (data['version'] ?? 0) as int,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
