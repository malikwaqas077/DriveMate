import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole; // "instructor" | "student"
  final String text;
  final DateTime? readAt;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  static Message fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Message(
      id: doc.id,
      conversationId: (data['conversationId'] ?? '') as String,
      senderId: (data['senderId'] ?? '') as String,
      senderRole: (data['senderRole'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Message copyWith({
    DateTime? readAt,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderRole: senderRole,
      text: text,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
