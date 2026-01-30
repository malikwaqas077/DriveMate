# DriveMate App - Notification Types

This document describes all the push notifications implemented in the DriveMate app.

## Overview

The app uses **Firebase Cloud Messaging (FCM)** to send push notifications. All notifications are handled by Cloud Functions that automatically trigger based on Firestore database changes.

---

## Notification Types

### 1. **New Lesson Scheduled** 📅
**Trigger:** When an instructor creates a new lesson for a student  
**Recipient:** Student  
**Function:** `onLessonCreated`

**Notification Details:**
- **Title:** "New Lesson Scheduled"
- **Body:** "You have a new lesson on [Day, Date Month] at [HH:MM]"
- **Example:** "You have a new lesson on Monday, 27 January at 05:15"
- **Data Payload:**
  - `type`: "lesson_created"
  - `lessonId`: ID of the created lesson

**When it fires:**
- Instructor schedules a new lesson for a student
- Student receives notification immediately

---

### 2. **Cancellation Request** 🚫
**Trigger:** When a student requests to cancel a lesson  
**Recipient:** Instructor  
**Function:** `onCancellationRequestCreated`

**Notification Details:**
- **Title:** "Cancellation Request"
- **Body:** "[Student Name] requested to cancel a lesson on [Day, Date Month]"
- **Example:** "John Doe requested to cancel a lesson on Monday, 27 January"
- **Data Payload:**
  - `type`: "cancellation_request"
  - `requestId`: ID of the cancellation request
  - `studentId`: ID of the student

**When it fires:**
- Student taps "Request Cancellation" button on a lesson
- Instructor receives notification to review the request

---

### 3. **Cancellation Response** ✅❌
**Trigger:** When an instructor approves or declines a cancellation request  
**Recipient:** Student  
**Function:** `onCancellationRequestResponded`

**Notification Details:**

**If Approved:**
- **Title:** "Cancellation Approved"
- **Body:** "Your lesson cancellation has been approved"
- **Data Payload:**
  - `type`: "cancellation_response"
  - `requestId`: ID of the cancellation request
  - `status`: "approved"

**If Declined:**
- **Title:** "Cancellation Declined"
- **Body:** "Your lesson cancellation request was declined"
- **Data Payload:**
  - `type`: "cancellation_response"
  - `requestId`: ID of the cancellation request
  - `status`: "declined"

**When it fires:**
- Instructor approves or declines a cancellation request
- Student receives notification with the decision
- If approved, hours are deducted from student balance according to cancellation policy

---

### 4. **Lesson Reminder** ⏰
**Trigger:** Scheduled function runs every hour  
**Recipient:** Student  
**Function:** `scheduleLessonReminders`

**Notification Details:**
- **Title:** "Lesson Reminder"
- **Body:** Varies based on time until lesson:
  - **Less than 2 hours:** "Your lesson is starting soon at [HH:MM]"
  - **2-12 hours:** "Don't forget your lesson [today/tomorrow] at [HH:MM]"
  - **12-24 hours:** "Reminder: You have a lesson [Day] at [HH:MM]"
- **Data Payload:**
  - `type`: "lesson_reminder"
  - `lessonId`: ID of the upcoming lesson

**When it fires:**
- Runs automatically every hour
- Checks for lessons in the next 24 hours
- Sends reminder based on instructor's `reminderHoursBefore` setting (default: 24 hours)
- Only sends one reminder per student per hour
- Only for lessons with status "scheduled" or null (not cancelled)

**Configuration:**
- Instructors can set `reminderHoursBefore` in their profile settings
- Default is 24 hours before the lesson

---

### 5. **New Lesson Reflection** 📝
**Trigger:** When a student adds or updates a reflection for a completed lesson  
**Recipient:** Instructor  
**Function:** `onReflectionAdded`

**Notification Details:**
- **Title:** "New Lesson Reflection"
- **Body:** "[Student Name] added a reflection for their lesson"
- **Example:** "John Doe added a reflection for their lesson"
- **Data Payload:**
  - `type`: "reflection_added"
  - `lessonId`: ID of the lesson
  - `studentId`: ID of the student

**When it fires:**
- Student completes a lesson reflection
- Student updates an existing reflection
- Instructor receives notification to review the reflection

---

## Notification Flow Summary

### Student → Instructor Notifications:
1. **Cancellation Request** - Student requests to cancel
2. **Lesson Reflection** - Student adds reflection

### Instructor → Student Notifications:
1. **New Lesson Scheduled** - Instructor creates lesson
2. **Cancellation Response** - Instructor approves/declines cancellation

### System → Student Notifications:
1. **Lesson Reminder** - Automated reminder before lesson

---

## Technical Requirements

### For Notifications to Work:

1. **FCM Token:**
   - User must be logged in on a device
   - FCM token is automatically saved to user profile when they log in
   - Token is stored in `users/{userId}.fcmToken`

2. **User-Student Link:**
   - Student's user profile must have `studentId` field set
   - Links the Firebase Auth user to the student record

3. **Cloud Functions:**
   - All functions are deployed and active
   - Functions automatically trigger on Firestore changes
   - No manual action required

4. **Permissions:**
   - App must have notification permissions granted
   - Android: Handled automatically
   - iOS: User must grant permission

---

## Notification Data Structure

All notifications include a `data` payload that can be used to:
- Navigate to specific screens when notification is tapped
- Update UI without full app refresh
- Track notification analytics

**Example data payload:**
```json
{
  "type": "cancellation_response",
  "requestId": "abc123",
  "status": "approved"
}
```

---

## Troubleshooting

### Notifications Not Received?

1. **Check FCM Token:**
   - Verify user is logged in
   - Check `users/{userId}.fcmToken` exists in Firestore

2. **Check Student Link:**
   - Verify `users/{userId}.studentId` is set
   - Must match the student ID in the lesson/cancellation request

3. **Check Cloud Functions:**
   - View logs: `firebase functions:log`
   - Verify functions are deployed and active

4. **Check Permissions:**
   - Ensure app has notification permissions
   - Check device notification settings

5. **Check Function Logs:**
   - Look for "No FCM token" messages
   - Look for "No user found for student" messages
   - These indicate missing data, not function errors

---

## Future Notification Ideas

Potential notifications that could be added:
- Payment reminders
- Payment received confirmations
- Lesson rescheduled notifications
- Instructor messages/replies
- Balance low warnings
- Test results available
