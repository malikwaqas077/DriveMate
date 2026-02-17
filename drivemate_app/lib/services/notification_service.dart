import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'chat_service.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Platform channel to send app back to background after handling an action
// ─────────────────────────────────────────────────────────────────────────────
const _kPlatformChannel = MethodChannel('app.techsol.drivemate/utils');

Future<void> _moveAppToBackground() async {
  try {
    debugPrint('[NOTIF] Requesting moveToBackground...');
    await _kPlatformChannel.invokeMethod('moveToBackground');
    debugPrint('[NOTIF] ✓ moveToBackground succeeded');
  } catch (e) {
    debugPrint('[NOTIF] moveToBackground error (non-fatal): $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: Notification action definitions (used in both FG and BG handlers)
// showsUserInterface MUST be true — Android 16 silently drops background
// action callbacks.  We compensate by calling moveTaskToBack() after handling.
// ─────────────────────────────────────────────────────────────────────────────
const _kChatActions = <AndroidNotificationAction>[
  AndroidNotificationAction(
    'MARK_READ',
    'Mark as Read',
    titleColor: Colors.green,
    showsUserInterface: true,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    'REPLY',
    'Reply',
    titleColor: Colors.blue,
    showsUserInterface: true,
    inputs: <AndroidNotificationActionInput>[
      AndroidNotificationActionInput(label: 'Type a reply...'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL: Background handler for notification ACTION responses
// (Mark as Read / Reply tapped while app is in background or terminated)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  debugPrint('');
  debugPrint('[NOTIF-BG-ACTION] ╔══════════════════════════════════════════╗');
  debugPrint('[NOTIF-BG-ACTION] ║  BACKGROUND ACTION HANDLER TRIGGERED    ║');
  debugPrint('[NOTIF-BG-ACTION] ╚══════════════════════════════════════════╝');
  debugPrint('[NOTIF-BG-ACTION] actionId       : "${response.actionId}"');
  debugPrint('[NOTIF-BG-ACTION] id             : ${response.id}');
  debugPrint('[NOTIF-BG-ACTION] payload        : ${response.payload}');
  debugPrint('[NOTIF-BG-ACTION] input          : "${response.input}"');
  debugPrint('[NOTIF-BG-ACTION] responseType   : ${response.notificationResponseType}');

  if (response.payload == null) {
    debugPrint('[NOTIF-BG-ACTION] payload is null → aborting');
    return;
  }

  final parts = response.payload!.split('|');
  debugPrint('[NOTIF-BG-ACTION] payload parts (${parts.length}): $parts');
  if (parts.length < 4) {
    debugPrint('[NOTIF-BG-ACTION] not enough parts → aborting');
    return;
  }

  final type = parts[0];
  final conversationId = parts[1];
  if (type != 'chat_message') {
    debugPrint('[NOTIF-BG-ACTION] type="$type" is not chat_message → aborting');
    return;
  }

  // Initialize Firebase in the background isolate
  debugPrint('[NOTIF-BG-ACTION] Initializing Firebase...');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[NOTIF-BG-ACTION] Firebase initialized (or was already)');
  } catch (e) {
    debugPrint('[NOTIF-BG-ACTION] Firebase init caught: $e');
  }

  final user = FirebaseAuth.instance.currentUser;
  debugPrint('[NOTIF-BG-ACTION] currentUser: ${user?.uid ?? "NULL"}');
  if (user == null) {
    debugPrint('[NOTIF-BG-ACTION] No authenticated user → aborting');
    return;
  }

  final firestoreService = FirestoreService();
  final chatService = ChatService();
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final notificationId = conversationId.hashCode;

  if (response.actionId == 'MARK_READ') {
    debugPrint('[NOTIF-BG-ACTION] ── MARK_READ start ──');
    try {
      final profile = await firestoreService.getUserProfile(user.uid);
      debugPrint('[NOTIF-BG-ACTION] profile: ${profile?.role ?? "NULL"}');
      if (profile != null) {
        await chatService.markAsRead(
          conversationId: conversationId,
          userId: user.uid,
          userRole: profile.role,
        );
        debugPrint('[NOTIF-BG-ACTION] ✓ Marked $conversationId as read');
      }
    } catch (e, st) {
      debugPrint('[NOTIF-BG-ACTION] ✗ Error marking as read: $e');
      debugPrint('[NOTIF-BG-ACTION] $st');
    }
    await notificationPlugin.cancel(notificationId);
    debugPrint('[NOTIF-BG-ACTION] ✓ Cancelled notification $notificationId');
    debugPrint('[NOTIF-BG-ACTION] ── MARK_READ done ──');
  } else if (response.actionId == 'REPLY') {
    final inputText = response.input?.trim();
    debugPrint('[NOTIF-BG-ACTION] ── REPLY start ── input="$inputText"');
    if (inputText != null && inputText.isNotEmpty) {
      try {
        final profile = await firestoreService.getUserProfile(user.uid);
        debugPrint('[NOTIF-BG-ACTION] profile: ${profile?.role ?? "NULL"}');
        if (profile != null) {
          await chatService.sendMessage(
            conversationId: conversationId,
            text: inputText,
            senderId: user.uid,
            senderRole: profile.role,
          );
          debugPrint('[NOTIF-BG-ACTION] ✓ Reply sent');
        }
      } catch (e, st) {
        debugPrint('[NOTIF-BG-ACTION] ✗ Error sending reply: $e');
        debugPrint('[NOTIF-BG-ACTION] $st');
      }
      await notificationPlugin.cancel(notificationId);
      debugPrint('[NOTIF-BG-ACTION] ✓ Cancelled notification $notificationId');
    } else {
      debugPrint('[NOTIF-BG-ACTION] input was empty, nothing to send');
    }
    debugPrint('[NOTIF-BG-ACTION] ── REPLY done ──');
  } else {
    debugPrint('[NOTIF-BG-ACTION] Unknown actionId="${response.actionId}"');
  }
  debugPrint('[NOTIF-BG-ACTION] handler finished');
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL: Background FCM message handler (shows the notification)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) {
    debugPrint('[NOTIF-FCM-BG] Skipping on web');
    return;
  }

  debugPrint('');
  debugPrint('[NOTIF-FCM-BG] ╔══════════════════════════════════════════╗');
  debugPrint('[NOTIF-FCM-BG] ║  FCM BACKGROUND MESSAGE HANDLER         ║');
  debugPrint('[NOTIF-FCM-BG] ╚══════════════════════════════════════════╝');
  debugPrint('[NOTIF-FCM-BG] messageId : ${message.messageId}');
  debugPrint('[NOTIF-FCM-BG] data      : ${message.data}');
  debugPrint('[NOTIF-FCM-BG] notif     : title="${message.notification?.title}" body="${message.notification?.body}"');

  // Initialize plugin in background isolate
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

  // IMPORTANT: Do NOT register onDidReceiveBackgroundNotificationResponse here!
  // The main isolate's NotificationService.initialize() already stored the
  // correct callback handle in SharedPreferences.  Re-registering from this
  // temporary FCM background isolate can overwrite that handle with one that
  // becomes invalid once this isolate terminates.
  debugPrint('[NOTIF-FCM-BG] Initializing notification plugin (no action callbacks)...');
  await notificationPlugin.initialize(initSettings);
  debugPrint('[NOTIF-FCM-BG] Plugin initialized (bare – callbacks from main isolate)');

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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    debugPrint('[NOTIF-FCM-BG] Chat channel created/ensured');
  }

  if (message.data['type'] == 'chat_message') {
    final conversationId = message.data['conversationId'] ?? '';
    final messageId = message.data['messageId'] ?? '';
    final senderId = message.data['senderId'] ?? '';
    final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : message.hashCode;
    final title = message.notification?.title ?? message.data['title'] ?? 'New Message';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final payload = 'chat_message|$conversationId|$messageId|$senderId';

    debugPrint('[NOTIF-FCM-BG] Chat message → notifId=$notificationId convId=$conversationId');
    debugPrint('[NOTIF-FCM-BG] title="$title" body="$body"');
    debugPrint('[NOTIF-FCM-BG] payload="$payload"');
    debugPrint('[NOTIF-FCM-BG] actions count: ${_kChatActions.length}');
    for (final a in _kChatActions) {
      debugPrint('[NOTIF-FCM-BG]   action id="${a.id}" showsUI=${a.showsUserInterface} cancelNotif=${a.cancelNotification} inputs=${a.inputs?.length ?? 0}');
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      actions: _kChatActions,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    debugPrint('[NOTIF-FCM-BG] Calling notificationPlugin.show()...');
    await notificationPlugin.show(notificationId, title, body, details, payload: payload);
    debugPrint('[NOTIF-FCM-BG] ✓ Notification shown');
  } else if (message.notification != null) {
    // Non-chat notification with notification payload (e.g. reflection_added,
    // lesson_created, cancellation_request, etc.):
    // The OS auto-displays the notification payload in background/terminated
    // state. Do NOT show a local notification — it would create a duplicate.
    debugPrint('[NOTIF-FCM-BG] Non-chat notification with payload → OS handles display, skipping local');
  } else {
    debugPrint('[NOTIF-FCM-BG] No chat data and no notification payload → nothing to show');
  }
  debugPrint('[NOTIF-FCM-BG] handler finished');
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASS: NotificationService singleton
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ChatService _chatService = ChatService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _initialized = false;
  final Set<int> _shownNotificationIds = <int>{};
  final Set<String> _shownMessageIds = <String>{};

  /// Track which conversation is currently active (user is viewing it)
  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    debugPrint('[NOTIF] Active conversation set to: $conversationId');
  }

  // ─── Initialize ──────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[NOTIF-INIT] Already initialized, skipping');
      return;
    }
    if (kIsWeb) {
      debugPrint('[NOTIF-INIT] Skipping on web');
      _initialized = true;
      return;
    }

    debugPrint('[NOTIF-INIT] ── Starting initialization ──');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    debugPrint('[NOTIF-INIT] Calling _localNotifications.initialize()'
        ' with onDidReceiveNotificationResponse=_onNotificationTapped'
        ' and onDidReceiveBackgroundNotificationResponse=onBackgroundNotificationResponse');
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );
    debugPrint('[NOTIF-INIT] Plugin initialized ✓');

    if (Platform.isAndroid) {
      await _createNotificationChannel();
      debugPrint('[NOTIF-INIT] Android channel created ✓');
    }

    _initialized = true;
    debugPrint('[NOTIF-INIT] ── Initialization complete ──');
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ─── Show notification from FCM message ──────────────────────────────────
  Future<void> showNotificationFromMessage(RemoteMessage message) async {
    final data = message.data;
    final isChatMessage = data['type'] == 'chat_message';

    debugPrint('[NOTIF-SHOW] showNotificationFromMessage called, isChatMessage=$isChatMessage');
    debugPrint('[NOTIF-SHOW] messageId=${message.messageId} data=$data');

    if (isChatMessage) {
      // Dedup by FCM message ID
      final fcmMessageId = message.messageId ?? '';
      if (fcmMessageId.isNotEmpty && _shownMessageIds.contains(fcmMessageId)) {
        debugPrint('[NOTIF-SHOW] Duplicate FCM message $fcmMessageId → skipping');
        return;
      }
      if (fcmMessageId.isNotEmpty) {
        _shownMessageIds.add(fcmMessageId);
        Future.delayed(const Duration(seconds: 30), () => _shownMessageIds.remove(fcmMessageId));
      }

      // Suppress for active conversation
      final conversationId = data['conversationId'] ?? '';
      if (conversationId.isNotEmpty && conversationId == _activeConversationId) {
        debugPrint('[NOTIF-SHOW] Active conversation $conversationId → suppressed');
        return;
      }

      final title = message.notification?.title ?? data['title'] ?? 'New Message';
      final body = message.notification?.body ?? data['body'] ?? '';
      final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : message.hashCode;

      debugPrint('[NOTIF-SHOW] Will show chat notification: id=$notificationId conv=$conversationId');
      await _showChatNotification(
        id: notificationId,
        title: title,
        body: body,
        conversationId: conversationId,
        messageId: data['messageId'] ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else {
      final notification = message.notification;
      if (notification == null) {
        debugPrint('[NOTIF-SHOW] Non-chat and no notification payload → nothing to show');
        return;
      }
      // Build parseable payload: type|key1=value1|key2=value2
      final dataMap = message.data;
      final payloadType = dataMap['type'] ?? 'unknown';
      final buffer = StringBuffer(payloadType);
      for (final entry in dataMap.entries) {
        if (entry.key != 'type') {
          buffer.write('|${entry.key}=${entry.value}');
        }
      }
      final payload = buffer.toString();
      debugPrint('[NOTIF-SHOW] Showing non-chat notification, payload=$payload');
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('default', 'Default Notifications',
              channelDescription: 'Default notification channel',
              importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    }
  }

  // ─── Show chat notification with action buttons ──────────────────────────
  Future<void> _showChatNotification({
    required int id,
    required String title,
    required String body,
    required String conversationId,
    required String messageId,
    required String senderId,
  }) async {
    final notificationId = conversationId.isNotEmpty ? conversationId.hashCode : id;

    if (_shownNotificationIds.contains(notificationId)) {
      debugPrint('[NOTIF-SHOW] Notification $notificationId already in tracking set → skipping');
      return;
    }

    _shownNotificationIds.add(notificationId);

    final payload = 'chat_message|$conversationId|$messageId|$senderId';

    debugPrint('[NOTIF-SHOW] ── Showing chat notification ──');
    debugPrint('[NOTIF-SHOW] notificationId : $notificationId');
    debugPrint('[NOTIF-SHOW] title          : "$title"');
    debugPrint('[NOTIF-SHOW] body           : "$body"');
    debugPrint('[NOTIF-SHOW] payload        : "$payload"');
    debugPrint('[NOTIF-SHOW] actions count  : ${_kChatActions.length}');
    for (final a in _kChatActions) {
      debugPrint('[NOTIF-SHOW]   action id="${a.id}" showsUI=${a.showsUserInterface} cancelNotif=${a.cancelNotification} inputs=${a.inputs?.length ?? 0}');
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      actions: _kChatActions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    debugPrint('[NOTIF-SHOW] Calling _localNotifications.show()...');
    await _localNotifications.show(notificationId, title, body, details, payload: payload);
    debugPrint('[NOTIF-SHOW] ✓ Notification shown successfully');

    Future.delayed(const Duration(seconds: 30), () => _shownNotificationIds.remove(notificationId));
  }

  // ─── FOREGROUND: Handle notification tap / action button ─────────────────
  void _onNotificationTapped(NotificationResponse response) async {
    debugPrint('');
    debugPrint('[NOTIF-FG] ╔══════════════════════════════════════════╗');
    debugPrint('[NOTIF-FG] ║  FOREGROUND RESPONSE HANDLER TRIGGERED   ║');
    debugPrint('[NOTIF-FG] ╚══════════════════════════════════════════╝');
    debugPrint('[NOTIF-FG] id             : ${response.id}');
    debugPrint('[NOTIF-FG] actionId       : "${response.actionId}"');
    debugPrint('[NOTIF-FG] payload        : ${response.payload}');
    debugPrint('[NOTIF-FG] input          : "${response.input}"');
    debugPrint('[NOTIF-FG] responseType   : ${response.notificationResponseType}');

    if (response.payload == null) {
      debugPrint('[NOTIF-FG] payload is null → aborting');
      return;
    }

    final parts = response.payload!.split('|');
    debugPrint('[NOTIF-FG] payload parts (${parts.length}): $parts');

    final type = parts[0];

    // ── Chat message handling ──
    if (type == 'chat_message' && parts.length >= 4) {
      final conversationId = parts[1];
      final messageId = parts[2];
      final senderId = parts[3];
      final notificationId = conversationId.hashCode;

      debugPrint('[NOTIF-FG] type=$type convId=$conversationId msgId=$messageId sender=$senderId notifId=$notificationId');

      // ── MARK_READ ──
      if (response.actionId == 'MARK_READ') {
        debugPrint('[NOTIF-FG] ── MARK_READ start ──');
        await _handleMarkAsRead(conversationId);
        debugPrint('[NOTIF-FG] Cancelling notification $notificationId...');
        await cancelNotification(notificationId);
        debugPrint('[NOTIF-FG] ✓ MARK_READ complete → moving app to background');
        await _moveAppToBackground();
      }
      // ── REPLY ──
      else if (response.actionId == 'REPLY') {
        final inputText = response.input?.trim();
        debugPrint('[NOTIF-FG] ── REPLY start ── inputText="$inputText"');
        if (inputText != null && inputText.isNotEmpty) {
          debugPrint('[NOTIF-FG] Sending inline reply...');
          await _handleInlineReply(conversationId, senderId, inputText);
          debugPrint('[NOTIF-FG] Cancelling notification $notificationId...');
          await cancelNotification(notificationId);
          debugPrint('[NOTIF-FG] ✓ REPLY complete → moving app to background');
          await _moveAppToBackground();
        } else {
          debugPrint('[NOTIF-FG] No input text → fallback to opening chat');
          _handleReplyAction(conversationId);
        }
      }
      // ── Regular tap (no actionId) ── stays in foreground (user wants to see chat)
      else {
        debugPrint('[NOTIF-FG] Regular body tap → navigating to chat');
        _handleNotificationTap(conversationId);
      }
    }
    // ── Non-chat notification tap (reflection_added, lesson_created, etc.) ──
    else if (type.isNotEmpty && type != 'chat_message') {
      debugPrint('[NOTIF-FG] Non-chat notification tap: type=$type');
      final data = <String, String>{'type': type};
      for (var i = 1; i < parts.length; i++) {
        final idx = parts[i].indexOf('=');
        if (idx > 0) {
          data[parts[i].substring(0, idx)] = parts[i].substring(idx + 1);
        }
      }
      debugPrint('[NOTIF-FG] Parsed data: $data');
      _actionStreamController.add({'action': 'NAVIGATE', ...data});
    } else {
      debugPrint('[NOTIF-FG] Unknown payload format → aborting');
    }
    debugPrint('[NOTIF-FG] handler finished');
  }

  // ─── Mark as read ────────────────────────────────────────────────────────
  Future<void> _handleMarkAsRead(String conversationId) async {
    debugPrint('[NOTIF-MARK] _handleMarkAsRead($conversationId)');
    try {
      final user = _authService.currentUser;
      debugPrint('[NOTIF-MARK] currentUser: ${user?.uid ?? "NULL"}');
      if (user == null) return;

      final profile = await _firestoreService.getUserProfile(user.uid);
      debugPrint('[NOTIF-MARK] profile: ${profile?.role ?? "NULL"}');
      if (profile == null) return;

      await _chatService.markAsRead(
        conversationId: conversationId,
        userId: user.uid,
        userRole: profile.role,
      );
      debugPrint('[NOTIF-MARK] ✓ Marked $conversationId as read');
    } catch (e, st) {
      debugPrint('[NOTIF-MARK] ✗ Error: $e');
      debugPrint('[NOTIF-MARK] $st');
    }
  }

  // ─── Inline reply ────────────────────────────────────────────────────────
  Future<void> _handleInlineReply(String conversationId, String senderId, String text) async {
    debugPrint('[NOTIF-REPLY] _handleInlineReply(conv=$conversationId, text="$text")');
    try {
      final user = _authService.currentUser;
      debugPrint('[NOTIF-REPLY] currentUser: ${user?.uid ?? "NULL"}');
      if (user == null) return;

      final profile = await _firestoreService.getUserProfile(user.uid);
      debugPrint('[NOTIF-REPLY] profile: ${profile?.role ?? "NULL"}');
      if (profile == null) return;

      debugPrint('[NOTIF-REPLY] Calling chatService.sendMessage...');
      await _chatService.sendMessage(
        conversationId: conversationId,
        text: text,
        senderId: user.uid,
        senderRole: profile.role,
      );
      debugPrint('[NOTIF-REPLY] ✓ Reply sent successfully');
    } catch (e, st) {
      debugPrint('[NOTIF-REPLY] ✗ Error: $e');
      debugPrint('[NOTIF-REPLY] $st');
      _handleReplyAction(conversationId);
    }
  }

  // ─── Fallback: open chat screen ──────────────────────────────────────────
  void _handleReplyAction(String conversationId) {
    debugPrint('[NOTIF-NAV] _handleReplyAction → streaming REPLY action for $conversationId');
    _actionStreamController.add({'action': 'REPLY', 'conversationId': conversationId});
  }

  void _handleNotificationTap(String conversationId) {
    debugPrint('[NOTIF-NAV] _handleNotificationTap → streaming OPEN_CHAT for $conversationId');
    _actionStreamController.add({'action': 'OPEN_CHAT', 'conversationId': conversationId});
  }

  // ─── Stream & cancel ────────────────────────────────────────────────────
  final _actionStreamController = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onNotificationAction =>
      _actionStreamController.stream;

  Future<void> cancelNotification(int id) async {
    debugPrint('[NOTIF] cancelNotification($id)');
    await _localNotifications.cancel(id);
    debugPrint('[NOTIF] ✓ cancel($id) returned');
  }

  Future<void> cancelAllNotifications() async {
    debugPrint('[NOTIF] cancelAllNotifications()');
    await _localNotifications.cancelAll();
  }

  void dispose() {
    _actionStreamController.close();
  }
}
