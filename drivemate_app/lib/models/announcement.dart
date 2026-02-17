import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  Announcement({
    required this.id,
    required this.schoolId,
    required this.authorId,
    required this.title,
    required this.body,
    this.audience = 'all',
    this.createdAt,
  });

  final String id;
  final String schoolId;
  final String authorId;
  final String title;
  final String body;
  final String audience; // 'all', 'instructors', 'students'
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'authorId': authorId,
      'title': title,
      'body': body,
      'audience': audience,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Announcement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Announcement(
      id: doc.id,
      schoolId: (data['schoolId'] ?? '') as String,
      authorId: (data['authorId'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      body: (data['body'] ?? '') as String,
      audience: (data['audience'] ?? 'all') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
