import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String? _currentToken;
  String? _currentUserId;

  /// Initialize FCM service - call after Firebase is initialized
  Future<void> initialize() async {
    debugPrint('[FCM] Initializing FCM service...');
    
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _requestPermission();

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    debugPrint('[FCM] ===== Setting up onMessageOpenedApp listener =====');
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        debugPrint('[FCM] ===== onMessageOpenedApp TRIGGERED! =====');
        debugPrint('[FCM] Message ID: ${message.messageId}');
        debugPrint('[FCM] Message data: ${message.data}');
        _handleMessageOpenedApp(message);
      },
      onError: (error) {
        debugPrint('[FCM] ===== ERROR in onMessageOpenedApp: $error =====');
      },
    );
    debugPrint('[FCM] ===== onMessageOpenedApp listener set up =====');

    // Check if app was opened from terminated state via notification
    debugPrint('[FCM] Checking for initial message...');
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Initial message found: ${initialMessage.messageId}');
      debugPrint('[FCM] Initial message data: ${initialMessage.data}');
      // Delay to ensure the app widget tree is built and listeners are ready
      Future.delayed(const Duration(milliseconds: 1000), () {
        debugPrint('[FCM] Processing initial message after delay...');
        _handleMessageOpenedApp(initialMessage);
      });
    } else {
      debugPrint('[FCM] No initial message found');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
    
    debugPrint('[FCM] FCM service initialized');
  }

  /// Request notification permissions
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    return authorized;
  }

  /// Get the current FCM token and save it to Firestore for the user
  Future<void> saveTokenForUser(String userId) async {
    _currentUserId = userId;

    try {
      final token = await _messaging.getToken();
      if (token != null && token != _currentToken) {
        _currentToken = token;
        await _firestoreService.updateUserProfile(userId, {
          'fcmToken': token,
        });
        debugPrint('[FCM] Token saved for user $userId');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting/saving token: $e');
    }
  }

  /// Clear token when user signs out
  Future<void> clearToken(String userId) async {
    try {
      await _firestoreService.updateUserProfile(userId, {
        'fcmToken': null,
      });
      _currentToken = null;
      _currentUserId = null;
      debugPrint('[FCM] Token cleared for user $userId');
    } catch (e) {
      debugPrint('[FCM] Error clearing token: $e');
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) async {
    if (_currentUserId != null && token != _currentToken) {
      _currentToken = token;
      await _firestoreService.updateUserProfile(_currentUserId!, {
        'fcmToken': token,
      });
      debugPrint('[FCM] Token refreshed and saved');
    }
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received: ${message.messageId}');
    debugPrint('[FCM] Title: ${message.notification?.title}');
    debugPrint('[FCM] Body: ${message.notification?.body}');
    debugPrint('[FCM] Data: ${message.data}');

    // Notify listeners about the message (for in-app UI updates)
    _notificationStreamController.add(message);
  }

  /// Handle notification tap (app opened from background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] ===== _handleMessageOpenedApp called =====');
    debugPrint('[FCM] App opened from notification: ${message.messageId}');
    debugPrint('[FCM] Title: ${message.notification?.title}');
    debugPrint('[FCM] Body: ${message.notification?.body}');
    debugPrint('[FCM] Data: ${message.data}');
    debugPrint('[FCM] Has listeners: ${_navigationStreamController.hasListener}');
    debugPrint('[FCM] Stream controller closed: ${_navigationStreamController.isClosed}');

    // Notify listeners for navigation
    if (!_navigationStreamController.isClosed) {
      _navigationStreamController.add(message);
      debugPrint('[FCM] ===== Message added to navigation stream successfully =====');
    } else {
      debugPrint('[FCM] ===== ERROR: Navigation stream controller is closed! =====');
    }
  }

  // Stream controllers for notifications
  final _notificationStreamController = 
      StreamController<RemoteMessage>.broadcast();
  final _navigationStreamController = 
      StreamController<RemoteMessage>.broadcast();

  /// Stream of foreground notifications (for in-app display)
  Stream<RemoteMessage> get onForegroundNotification =>
      _notificationStreamController.stream;

  /// Stream of notification taps (for navigation)
  Stream<RemoteMessage> get onNotificationTap =>
      _navigationStreamController.stream;

  /// Dispose streams
  void dispose() {
    _notificationStreamController.close();
    _navigationStreamController.close();
  }
}
