Data Model (Firestore)

Collections

users
- id (uid)
- role: "owner" | "instructor" | "student"
- name
- email
- phone (optional)
- schoolId (owner/instructor only)
- studentId (student only, links to students collection)
- acceptedTermsVersion (student only, optional)
- acceptedTermsAt (student only, optional)
- fcmToken (optional, FCM device token for push notifications)
- cancellationPolicy (instructor only, optional):
  - windowHours: number (12, 24, 48, 72)
  - chargePercent: number (25, 50, 75, 100)
- reminderHoursBefore (instructor only, optional): number (1, 2, 6, 12, 24)
- createdAt

schools
- id
- name
- ownerId (uid)
- createdAt
- status: "active" | "inactive"

school_instructors
- id
- schoolId
- instructorId (uid)
- feeAmount (number)
- feeFrequency: "week" | "month"
- active (bool)
- createdAt

access_requests
- id
- schoolId
- ownerId (uid)
- instructorId (uid)
- status: "pending" | "approved" | "rejected"
- createdAt
- respondedAt (optional)

cancellation_requests
- id
- lessonId
- studentId
- instructorId (uid)
- schoolId
- status: "pending" | "approved" | "declined"
- reason (optional)
- chargePercent: number (calculated at request time based on policy)
- hoursToDeduct: number (lesson duration)
- lessonStartAt (timestamp, for display purposes)
- createdAt
- respondedAt (optional)

students
- id
- instructorId (uid)
- schoolId
- name
- email (optional)
- phone (optional)
- hourlyRate (optional)
- balanceHours (number)
- status: "active" | "inactive" | "passed" | "other"
- createdAt

lessons
- id
- instructorId (uid)
- studentId
- schoolId
- startAt (timestamp)
- durationHours (number)
- lessonType: "lesson" | "mock_test" | "test"
- status: "scheduled" | "completed" | "cancelled"
- notes (optional)
- studentReflection (optional)
- createdAt
- updatedAt

payments
- id
- instructorId (uid)
- studentId
- schoolId
- amount (number)
- currency (e.g. "GBP")
- method: "cash" | "bank_transfer" | "card" | "other"
- paidTo: "instructor" | "school"
- hoursPurchased (number)
- createdAt

aggregates (optional)
- id
- instructorId (uid)
- periodType: "week" | "month" | "year"
- periodStart (timestamp)
- totalEarnings

instructor_balances (optional)
- id
- instructorId (uid)
- schoolId
- periodType: "week" | "month"
- periodStart (timestamp)
- totalPaidToInstructor
- totalPaidToSchool
- feeAmount
- netBalance

terms
- id (instructorId)
- text
- version (number)
- updatedAt

Balance Logic
- When payment is created:
  - students.balanceHours += payments.hoursPurchased
- When lesson is created:
  - students.balanceHours -= lessons.durationHours
- When lesson is updated:
  - delta = newDuration - oldDuration
  - students.balanceHours -= delta
- When lesson is deleted:
  - students.balanceHours += lessons.durationHours
- When cancellation is approved:
  - lessons.status = "cancelled"
  - hoursCharged = hoursToDeduct * (chargePercent / 100)
  - students.balanceHours -= hoursCharged (partial refund, hours already deducted when lesson created)

Push Notifications (Firebase Cloud Functions)
- onLessonCreated: Notify student of new scheduled lesson
- onReflectionAdded: Notify instructor when student adds reflection
- onCancellationRequestCreated: Notify instructor of new cancellation request
- onCancellationRequestResponded: Notify student of approval/decline
- scheduleLessonReminders: Hourly job to send reminders based on instructor settings

Reporting
- Use Cloud Function to write aggregates per instructor
- Alternatively compute in-app with Firestore queries (MVP OK)
