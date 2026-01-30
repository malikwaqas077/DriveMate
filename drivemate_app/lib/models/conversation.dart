import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  Conversation({
    required this.id,
    required this.instructorId,
    required this.studentId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageBy,
    this.unreadCountInstructor = 0,
    this.unreadCountStudent = 0,
    this.createdAt,
  });

  final String id;
  final String instructorId;
  final String studentId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageBy;
  final int unreadCountInstructor;
  final int unreadCountStudent;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'studentId': studentId,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      if (lastMessageBy != null) 'lastMessageBy': lastMessageBy,
      'unreadCountInstructor': unreadCountInstructor,
      'unreadCountStudent': unreadCountStudent,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  static Conversation fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Conversation(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageBy: data['lastMessageBy'] as String?,
      unreadCountInstructor: (data['unreadCountInstructor'] ?? 0) as int,
      unreadCountStudent: (data['unreadCountStudent'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageBy,
    int? unreadCountInstructor,
    int? unreadCountStudent,
  }) {
    return Conversation(
      id: id,
      instructorId: instructorId,
      studentId: studentId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      unreadCountInstructor:
          unreadCountInstructor ?? this.unreadCountInstructor,
      unreadCountStudent: unreadCountStudent ?? this.unreadCountStudent,
      createdAt: createdAt,
    );
  }
}
