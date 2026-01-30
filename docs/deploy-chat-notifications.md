# Deploy Chat Push Notifications

## Overview
The chat push notification Cloud Function has been created but needs to be deployed to Firebase.

## Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Logged into Firebase: `firebase login`
3. Node.js installed (version 20 as specified in package.json)

## Deployment Steps

### 1. Navigate to Functions Directory
```bash
cd functions
```

### 2. Install Dependencies (if not already done)
```bash
npm install
```

### 3. Build the Functions
```bash
npm run build
```

### 4. Deploy the Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy only the chat notification function
firebase deploy --only functions:onMessageCreated
```

### 5. Verify Deployment
After deployment, you can check the function logs:
```bash
firebase functions:log
```

## Testing

### Test Push Notifications
1. Send a message from one user (instructor or student)
2. The recipient should receive a push notification
3. Check Firebase Console > Functions > Logs for any errors

### Troubleshooting

#### No notifications received:
1. **Check FCM tokens**: Ensure users have FCM tokens saved in their user profile
2. **Check function logs**: `firebase functions:log` to see if function is being triggered
3. **Check app permissions**: Ensure notification permissions are granted on the device
4. **Verify function is deployed**: Check Firebase Console > Functions to see if `onMessageCreated` is listed

#### Function not triggering:
1. **Check Firestore rules**: Ensure the function can read/write to Firestore
2. **Check function path**: The function listens to `conversations/{conversationId}/messages/{messageId}`
3. **Verify message structure**: Messages must have `senderId`, `senderRole`, and `text` fields

#### Common Issues:
- **Missing FCM token**: User needs to open the app at least once to register FCM token
- **Function timeout**: Increase timeout in function configuration if needed
- **Permission errors**: Check Firebase IAM roles for the service account

## Function Details

The `onMessageCreated` function:
- Triggers when a new message is created in any conversation
- Finds the recipient (instructor or student)
- Gets the recipient's FCM token
- Sends a push notification with the sender's name and message preview
- Includes notification data for navigation when tapped

## Cost Impact
- Each message triggers 1 function invocation
- Minimal cost: ~$0.002 per 1000 messages
- See `docs/chat-feature-analysis.md` for detailed cost breakdown
