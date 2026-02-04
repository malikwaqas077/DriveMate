import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'chat_service.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

/// Background message handler - must be a top-level function
/// This is called when app is in background or terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notifications via `dart:io` / local notifications are not supported on web.
  // Guard early to avoid `Platform._operatingSystem` errors on Flutter web.
  if (kIsWeb) {
    debugPrint('[Notification] Skipping background handler on web');
    return;
  }

  debugPrint('[Notification] Background message: ${message.messageId}');
  
  // Initialize notification plugin for background isolate
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await notificationPlugin.initialize(initSettings);
  
  // Create channel if Android
  if (Platform.isAndroid) {
    const androidChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await notificationPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
  
  // Show notification for chat messages (data-only messages)
  // For chat messages, we send data-only, so get title/body from data
  if (message.data['type'] == 'chat_message') {
    final conversationId = message.data['conversationId'] ?? '';
    final messageId = message.data['messageId'] ?? '';
    final senderId = message.data['senderId'] ?? '';
    
    // Use conversationId hash for consistent notification ID
    final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : message.hashCode;
    
    // Prevent duplicate notifications in background handler
    // Note: This is a simple in-memory check. For production, consider using SharedPreferences
    // or a more robust solution if needed across app restarts
    debugPrint('[Notification] Background handler: Checking notification ID $notificationId');
    
    // Get title and body from data (data-only message) or notification field
    final title = message.notification?.title ?? message.data['title'] ?? 'New Message';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    
    debugPrint('[Notification] Background handler: Showing notification for conversation: $conversationId');
    
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'MARK_READ',
          'Mark as Read',
          titleColor: Colors.green,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'REPLY',
          'Reply',
          titleColor: Colors.blue,
          showsUserInterface: true,
        ),
      ],
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await notificationPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: 'chat_message|$conversationId|$messageId|$senderId',
    );
  } else if (message.notification != null) {
    // Show regular notification for non-chat messages
    await notificationPlugin.show(
      message.hashCode,
      message.notification!.title ?? '',
      message.notification!.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'Default Notifications',
          channelDescription: 'Default notification channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ChatService _chatService = ChatService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _initialized = false;
  // Track shown notification IDs to prevent duplicates
  final Set<int> _shownNotificationIds = <int>{};

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Local notifications and `Platform.isAndroid` are not supported on web.
    // Skip initialization entirely on web to prevent runtime errors.
    if (kIsWeb) {
      debugPrint('[Notification] Skipping notification initialization on web');
      _initialized = true;
      return;
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for chat messages (heads-up notifications)
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
    debugPrint('[Notification] Notification service initialized');
  }

  /// Create Android notification channel with heads-up support
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'chat_messages', // channel id
      'Chat Messages', // channel name
      description: 'Notifications for chat messages',
      importance: Importance.high, // High importance = heads-up notification
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show notification from FCM message with actions
  Future<void> showNotificationFromMessage(RemoteMessage message) async {
    final data = message.data;
    final isChatMessage = data['type'] == 'chat_message';

    if (isChatMessage) {
      // For chat messages, get title/body from data (data-only FCM message)
      final title = message.notification?.title ?? data['title'] ?? 'New Message';
      final body = message.notification?.body ?? data['body'] ?? '';
      final conversationId = data['conversationId'] ?? '';
      
      // Use conversationId hash for consistent notification ID
      // This ensures we can cancel/replace notifications properly
      final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : message.hashCode;
      
      // Show chat notification with actions
      await _showChatNotification(
        id: notificationId,
        title: title,
        body: body,
        conversationId: conversationId,
        messageId: data['messageId'] ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else {
      // Show regular notification
      final notification = message.notification;
      if (notification == null) return;
      
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default',
            'Default Notifications',
            channelDescription: 'Default notification channel',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Show chat notification with action buttons
  Future<void> _showChatNotification({
    required int id,
    required String title,
    required String body,
    required String conversationId,
    required String messageId,
    required String senderId,
  }) async {
    // Use a consistent ID based on conversationId to allow cancelling by conversation
    // This ensures we can cancel notifications even if the hash changes
    final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : id;
    
    // Prevent duplicate notifications
    if (_shownNotificationIds.contains(notificationId)) {
      debugPrint('[Notification] Notification $notificationId already shown, skipping duplicate');
      return;
    }
    
    _shownNotificationIds.add(notificationId);
    debugPrint('[Notification] Showing chat notification ID: $notificationId for conversation: $conversationId');
    
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high, // Heads-up notification
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'MARK_READ',
          'Mark as Read',
          titleColor: Colors.green,
          cancelNotification: true, // This should dismiss the notification
        ),
        AndroidNotificationAction(
          'REPLY',
          'Reply',
          titleColor: Colors.blue,
          showsUserInterface: true, // Opens app for reply
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: 'chat_message|$conversationId|$messageId|$senderId',
    );
    
    // Remove from tracking set after a delay to allow for updates
    Future.delayed(const Duration(seconds: 5), () {
      _shownNotificationIds.remove(notificationId);
    });
  }

  /// Handle notification tap or action button tap
  void _onNotificationTapped(NotificationResponse response) async {
    debugPrint('[Notification] Notification tapped: ${response.id}');
    debugPrint('[Notification] Action: ${response.actionId}');
    debugPrint('[Notification] Payload: ${response.payload}');

    if (response.payload == null) return;

    final parts = response.payload!.split('|');
    if (parts.length < 4) return;

    final type = parts[0];
    final conversationId = parts[1];
    final messageId = parts[2];
    final senderId = parts[3];

    if (type != 'chat_message') return;

    // Handle action buttons
    if (response.actionId == 'MARK_READ') {
      await _handleMarkAsRead(conversationId);
      // Cancel the notification after marking as read
      // Use conversationId hash to match the notification ID used in _showChatNotification
      final notificationId = conversationId.hashCode;
      debugPrint('[Notification] Cancelling notification ID: $notificationId for conversation: $conversationId');
      await cancelNotification(notificationId);
    } else if (response.actionId == 'REPLY') {
      // Reply action - open app to chat screen
      _handleReplyAction(conversationId);
    } else {
      // Regular tap - navigate to chat
      _handleNotificationTap(conversationId);
    }
  }

  /// Handle mark as read action
  Future<void> _handleMarkAsRead(String conversationId) async {
    try {
      // Get current user
      final user = _authService.currentUser;
      if (user == null) return;

      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile == null) return;

      await _chatService.markAsRead(
        conversationId: conversationId,
        userId: user.uid,
        userRole: profile.role,
      );

      debugPrint('[Notification] Marked conversation $conversationId as read');
    } catch (e) {
      debugPrint('[Notification] Error marking as read: $e');
    }
  }

  /// Handle reply action
  void _handleReplyAction(String conversationId) {
    // Notify listeners to open chat screen
    _actionStreamController.add({
      'action': 'REPLY',
      'conversationId': conversationId,
    });
    debugPrint('[Notification] Reply action for conversation: $conversationId');
  }

  /// Handle notification tap
  void _handleNotificationTap(String conversationId) {
    // Notify listeners to navigate to chat
    _actionStreamController.add({
      'action': 'OPEN_CHAT',
      'conversationId': conversationId,
    });
    debugPrint('[Notification] Tap action for conversation: $conversationId');
  }

  // Stream controller for notification actions
  final _actionStreamController = StreamController<Map<String, String>>.broadcast();

  /// Stream of notification actions
  Stream<Map<String, String>> get onNotificationAction =>
      _actionStreamController.stream;

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Dispose streams
  void dispose() {
    _actionStreamController.close();
  }
}
