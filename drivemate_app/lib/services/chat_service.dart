import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Get or create a conversation between instructor and student
  Future<String> getOrCreateConversation({
    required String instructorId,
    required String studentId,
  }) async {
    // Try to find existing conversation
    final existingQuery = await _conversations
        .where('instructorId', isEqualTo: instructorId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      return existingQuery.docs.first.id;
    }

    // Create new conversation
    final doc = await _conversations.add({
      'instructorId': instructorId,
      'studentId': studentId,
      'unreadCountInstructor': 0,
      'unreadCountStudent': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderRole,
  }) async {
    final conversationRef = _conversations.doc(conversationId);
    final messagesRef = conversationRef.collection('messages');

    // Create message
    final messageData = {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Update conversation metadata and increment unread count
    await _db.runTransaction((tx) async {
      final conversationDoc = await tx.get(conversationRef);
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversationData = conversationDoc.data()!;
      final isInstructor = senderRole == 'instructor';
      final unreadField = isInstructor
          ? 'unreadCountStudent'
          : 'unreadCountInstructor';

      // Add message
      tx.set(messagesRef.doc(), messageData);

      // Update conversation
      tx.update(conversationRef, {
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': senderId,
        unreadField: FieldValue.increment(1),
      });
    });
  }

  /// Stream messages for a conversation
  Stream<List<Message>> streamMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromDoc(doc)).toList());
  }

  /// Get conversations for an instructor
  Stream<List<Conversation>> streamInstructorConversations(
    String instructorId,
  ) {
    return _conversations
        .where('instructorId', isEqualTo: instructorId)
        .snapshots()
        .map((snapshot) {
      final conversations =
          snapshot.docs.map((doc) => Conversation.fromDoc(doc)).toList();
      // Sort by lastMessageAt descending, nulls last
      conversations.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
      return conversations;
    });
  }

  /// Get conversations for a student
  Stream<List<Conversation>> streamStudentConversations(String studentId) {
    return _conversations
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final conversations =
          snapshot.docs.map((doc) => Conversation.fromDoc(doc)).toList();
      // Sort by lastMessageAt descending, nulls last
      conversations.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
      return conversations;
    });
  }

  /// Mark messages as read in a conversation
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
    required String userRole,
  }) async {
    final conversationRef = _conversations.doc(conversationId);
    final messagesRef = conversationRef.collection('messages');

    // Get all messages that are unread and not sent by current user
    // Note: We can't use compound query with isNotEqualTo and isNull, so we'll filter in code
    final allMessages = await messagesRef.get();
    final unreadMessages = allMessages.docs.where((doc) {
      final data = doc.data();
      return data['senderId'] != userId && data['readAt'] == null;
    }).toList();

    if (unreadMessages.isEmpty) {
      // Just update unread count to 0
      final unreadField =
          userRole == 'instructor' ? 'unreadCountInstructor' : 'unreadCountStudent';
      await conversationRef.update({
        unreadField: 0,
      });
      return;
    }

    // Mark messages as read and update unread count
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    for (final doc in unreadMessages) {
      batch.update(doc.reference, {'readAt': now});
    }

    final unreadField =
        userRole == 'instructor' ? 'unreadCountInstructor' : 'unreadCountStudent';
    batch.update(conversationRef, {unreadField: 0});

    await batch.commit();
  }

  /// Get total unread message count for a user
  Stream<int> streamTotalUnreadCount(String userId, String userRole) {
    if (userRole == 'instructor') {
      return _conversations
          .where('instructorId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        int total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          total += (data['unreadCountInstructor'] ?? 0) as int;
        }
        return total;
      });
    } else {
      // For students, we need studentId, not userId
      // This will be handled differently - we'll need to pass studentId
      return Stream.value(0);
    }
  }

  /// Get total unread message count for a student
  Stream<int> streamTotalUnreadCountForStudent(String studentId) {
    return _conversations
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        total += (data['unreadCountStudent'] ?? 0) as int;
      }
      return total;
    });
  }

  /// Get a single conversation
  Future<Conversation?> getConversation(String conversationId) async {
    final doc = await _conversations.doc(conversationId).get();
    if (!doc.exists) return null;
    return Conversation.fromDoc(doc);
  }

  /// Get student name for display
  Future<String> getStudentName(String studentId) async {
    final studentDoc = await _db.collection('students').doc(studentId).get();
    if (!studentDoc.exists) return 'Student';
    return studentDoc.data()?['name'] ?? 'Student';
  }

  /// Get instructor name for display
  Future<String> getInstructorName(String instructorId) async {
    final instructorDoc =
        await _db.collection('users').doc(instructorId).get();
    if (!instructorDoc.exists) return 'Instructor';
    return instructorDoc.data()?['name'] ?? 'Instructor';
  }
}
