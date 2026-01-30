# Heads-Up Notifications & Action Buttons Setup

## Overview
This document explains the implementation of WhatsApp-like heads-up notifications with action buttons for chat messages.

## Features Implemented

### 1. Heads-Up Notifications
- Notifications appear as banners on the screen (like WhatsApp)
- Automatically disappear after a few seconds
- High priority notifications that appear even when screen is locked

### 2. Action Buttons
- **Mark as Read**: Marks the conversation as read without opening the app
- **Reply**: Opens the app and navigates to the chat screen

## Implementation Details

### Android Setup

#### Notification Channel
- Created `chat_messages` channel with `IMPORTANCE_HIGH`
- This enables heads-up (banner) notifications
- Channel is created automatically by `NotificationService`

#### Dependencies Added
- `flutter_local_notifications: ^17.2.3` - For custom notification display and actions

### Flutter Implementation

#### Files Created/Modified:

1. **`lib/services/notification_service.dart`** (NEW)
   - Handles local notification display with actions
   - Creates Android notification channel
   - Handles action button clicks
   - Shows heads-up notifications for chat messages

2. **`lib/services/fcm_service.dart`** (MODIFIED)
   - Integrated with NotificationService
   - Shows local notifications for chat messages in foreground
   - Background handler uses NotificationService

3. **`lib/main.dart`** (MODIFIED)
   - Initializes NotificationService before FCMService

4. **`lib/app.dart`** (MODIFIED)
   - Listens for notification action button clicks
   - Handles navigation when "Reply" is tapped

5. **`functions/src/index.ts`** (MODIFIED)
   - Updated to use `chat_messages` channel for chat notifications
   - Sets high priority for heads-up display

## How It Works

### When a Message is Received:

1. **Cloud Function** (`onMessageCreated`) triggers
2. Sends FCM notification with `chat_messages` channel
3. **NotificationService** intercepts the notification
4. Displays local notification with:
   - Heads-up banner (appears on screen)
   - Action buttons: "Mark as Read" and "Reply"
   - Sound and vibration

### Action Button Behavior:

#### "Mark as Read" Button:
- Marks all unread messages in the conversation as read
- Updates Firestore unread count to 0
- Dismisses the notification
- **No app opening required**

#### "Reply" Button:
- Opens the app (if closed)
- Navigates to Conversations List screen
- User can then open the specific chat

## Testing

### Test Heads-Up Notifications:
1. Send a message from one device
2. On recipient device, notification should appear as a banner
3. Banner should auto-dismiss after a few seconds

### Test Action Buttons:
1. When notification appears, swipe down to see actions
2. Tap "Mark as Read" - notification should dismiss, conversation marked as read
3. Tap "Reply" - app should open to chat screen

### Test Background Notifications:
1. Close the app completely
2. Send a message
3. Notification should appear with actions
4. Actions should work even when app is closed

## Troubleshooting

### Notifications not showing as heads-up:
- Check Android notification channel importance (should be HIGH)
- Verify notification channel is created (check logs)
- Ensure device Do Not Disturb is not enabled
- Check app notification permissions

### Action buttons not working:
- Verify `flutter_local_notifications` is properly initialized
- Check notification payload format
- Verify action IDs match: `MARK_READ` and `REPLY`

### Notifications not appearing at all:
- Check FCM token is saved in Firestore
- Verify Cloud Function is deployed
- Check function logs: `firebase functions:log`
- Verify notification permissions are granted

## Next Steps (Optional Enhancements)

### Inline Reply (Like WhatsApp):
To add inline reply from notification (without opening app):
1. Use Android's `RemoteInput` API
2. Add text input field to notification
3. Handle reply text in background
4. Send message via Cloud Function

### Notification Grouping:
- Group multiple messages from same conversation
- Show summary: "3 new messages from John"

### Rich Notifications:
- Show sender avatar in notification
- Show message preview with formatting
- Add image preview if message contains image

## Deployment

After making changes:
1. Run `flutter pub get` to install `flutter_local_notifications`
2. Rebuild the app: `flutter build apk` or `flutter build appbundle`
3. Deploy Cloud Functions: `cd functions && npm run build && firebase deploy --only functions`

## Notes

- Heads-up notifications work on Android 5.0+ (API 21+)
- iOS notifications appear differently (system handles them)
- Action buttons are Android-specific feature
- Background notifications require proper FCM setup
