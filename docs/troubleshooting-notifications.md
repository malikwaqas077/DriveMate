# Troubleshooting Instructor Notifications

## Issue: Student Not Receiving "On Way" or "Arrived" Notifications

### Step 1: Verify Cloud Function is Deployed

The Cloud Function `onInstructorNotificationCreated` must be deployed for notifications to work.

**Check if deployed:**
```bash
cd functions
firebase functions:list
```

**If not deployed, deploy it:**
```bash
cd functions
npm install
firebase deploy --only functions:onInstructorNotificationCreated
```

### Step 2: Verify Student Setup

1. **Student must have a user account:**
   - Check Firestore: `users` collection
   - Look for a document where `studentId` matches the student's ID
   - If missing, the student needs to log in to the app first

2. **Student must have FCM token:**
   - Check Firestore: `users/{userId}.fcmToken` field
   - Must not be null or empty
   - Token is automatically saved when student logs in on their device

### Step 3: Check Firestore Documents

When instructor clicks "On Way" or "Arrived":
1. A document should be created in `instructor_notifications` collection
2. Check Firestore console to see if document appears
3. Document should be automatically deleted after Cloud Function processes it

### Step 4: Check Cloud Function Logs

View logs to see what's happening:
```bash
cd functions
firebase functions:log --only onInstructorNotificationCreated
```

**Common log messages:**
- ✅ `Sent on_way notification to student...` - Success!
- ❌ `No user profile found for student...` - Student doesn't have app account
- ❌ `No FCM token for student...` - Student hasn't logged in on device
- ❌ `Invalid notification data...` - Missing required fields

### Step 5: Verify Notification Flow

1. **Instructor clicks "On Way":**
   - App creates document in `instructor_notifications`
   - Cloud Function triggers automatically
   - Function gets student's FCM token
   - Function sends push notification
   - Document is deleted

2. **Student receives notification:**
   - Title: "Instructor On Way" or "Instructor Arrived"
   - Body: "[Instructor Name] is on their way to you" or "[Instructor Name] has arrived"
   - Tapping notification opens student's lessons screen

### Step 6: Debug Checklist

- [ ] Cloud Function is deployed
- [ ] Student has user account in Firestore (`users` collection with `studentId` field)
- [ ] Student has FCM token (`users/{userId}.fcmToken` is not null)
- [ ] Student is logged in on their device
- [ ] Student has notification permissions enabled
- [ ] Document appears in `instructor_notifications` when instructor clicks button
- [ ] Cloud Function logs show the notification being sent
- [ ] No errors in Cloud Function logs

### Common Issues

**Issue: "Student does not have an app account"**
- Solution: Student needs to log in to the app at least once
- Instructor should create login for student if not already done

**Issue: "Student has not enabled notifications"**
- Solution: Student needs to log in on their device (FCM token is generated on login)
- Check that student's device has internet connection

**Issue: Document created but no notification sent**
- Check Cloud Function logs for errors
- Verify student's FCM token is valid
- Check if Cloud Function is actually deployed

**Issue: Notification sent but student doesn't receive it**
- Check student's device notification settings
- Verify student is logged in on the device
- Check if FCM token is still valid (may need to re-login)
