Lean MVP Spec (v0)

Stack
- Mobile: Flutter
- Backend: Firebase (Auth + Firestore + Cloud Functions + FCM)
- Web portal: Flutter Web (same repo; instructor only)

Users & Roles
- Owner: manages school and instructors; views instructor reports
- Instructor: full CRUD on students, lessons, payments; views reports; uses mobile + web
- Student: read-only on own profile, lessons, balance

Core Flows
1) Auth
   - Email/password sign up for Instructor and Student
   - Role stored on user profile in Firestore

2) Student management (Instructor)
   - Create/edit/deactivate student profile
   - Assign hourly rate (optional) and starting prepaid hours balance (e.g. 10 hours)
   - View student balance and lesson history
   - Set student status (active, inactive, passed, etc.) and filter list by status tags

3) Lesson scheduling
   - Instructor calendar (week view default)
   - Tap/click to add lesson at date/time with duration
   - Lesson linked to a student

4) Payments
   - Instructor records payments with method (cash, bank transfer, other)
- Payment can be marked as paid to instructor or school
   - Payment adds hours to student balance

5) Auto balance deduction
   - When a lesson is created, subtract lesson duration from balance
   - If lesson is edited or deleted, adjust balance accordingly

6) Student view
   - Sections for upcoming lessons and past lessons
   - Profile shows totals in hours:
     - Total hours paid (sum of payments)
     - Total hours completed (lessons taken)
     - Remaining credit hours (current balance)
   - Student sees payment history (each payment made)

7) Reports (Instructor)
   - Earnings by week / month / year
   - Filter by date range

Non-Goals for MVP
- Online payments (Stripe later)
- Messaging/chat
- Advanced reporting exports

Default UX
- Calendar week view for Instructor (Mon-Sun)
- Quick add lesson by tapping time slot
- Student list with balance badge and status filter tags
