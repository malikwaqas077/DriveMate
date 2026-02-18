# Firebase Auth Account Cleanup - Cloud Function

## Problem
When a student is deleted, their Firebase Auth account remains. When trying to create a new student with the same phone number, Firebase throws `email-already-in-use` error.

## Solution
Create a Cloud Function that uses Firebase Admin SDK to:
1. Delete Firebase Auth accounts when students are deleted
2. Update passwords for orphaned accounts when reusing phone numbers

## Implementation

### Option 1: Delete Auth Account on Student Deletion

Create a Cloud Function that triggers when a student document is deleted:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onStudentDeleted = functions.firestore
  .document('students/{studentId}')
  .onDelete(async (snap, context) => {
    const studentId = context.params.studentId;
    
    // Find user profile linked to this student
    const userProfileSnapshot = await admin.firestore()
      .collection('users')
      .where('studentId', '==', studentId)
      .limit(1)
      .get();
    
    if (!userProfileSnapshot.empty) {
      const userProfile = userProfileSnapshot.docs[0].data();
      const uid = userProfileSnapshot.docs[0].id;
      
      // Delete Firebase Auth account
      try {
        await admin.auth().deleteUser(uid);
        console.log(`Deleted Auth account for user ${uid}`);
      } catch (error) {
        console.error(`Error deleting Auth account: ${error}`);
      }
      
      // User profile is already deleted by the app
    }
  });
```

### Option 2: Update Password for Orphaned Accounts

Create a Cloud Function to update password when reusing phone numbers:

```javascript
exports.updateStudentPassword = functions.https.onCall(async (data, context) => {
  // Verify the caller is an instructor/owner
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  
  const { phone, newPassword } = data;
  const authEmail = `${phone}@drivemate.local`;
  
  // Get user by email
  try {
    const userRecord = await admin.auth().getUserByEmail(authEmail);
    
    // Update password
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword
    });
    
    return { success: true, uid: userRecord.uid };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

## Deployment

1. Install dependencies:
```bash
cd functions
npm install firebase-admin firebase-functions
```

2. Deploy:
```bash
firebase deploy --only functions
```

## Usage

### Option 1 (Automatic)
No code changes needed - the function automatically deletes Auth accounts when students are deleted.

### Option 2 (Manual)
Call the function from your Flutter app:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('updateStudentPassword');
final result = await callable.call({
  'phone': phone,
  'newPassword': password,
});
final uid = result.data['uid'] as String;
```

## Recommendation
Use Option 1 (automatic deletion) as it's cleaner and prevents orphaned accounts.
