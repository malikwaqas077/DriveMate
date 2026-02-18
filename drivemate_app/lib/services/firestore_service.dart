import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/access_request.dart';
import '../models/achievement.dart';
import '../models/announcement.dart';
import '../models/cancellation_request.dart';
import '../models/competency.dart';
import '../models/expense.dart';
import '../models/lesson.dart';
import '../models/payment.dart';
import '../models/recurring_template.dart';
import '../models/school.dart';
import '../models/school_instructor.dart';
import '../models/student.dart';
import '../models/terms.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _students =>
      _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _lessons =>
      _db.collection('lessons');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('payments');
  CollectionReference<Map<String, dynamic>> get _terms =>
      _db.collection('terms');
  CollectionReference<Map<String, dynamic>> get _schools =>
      _db.collection('schools');
  CollectionReference<Map<String, dynamic>> get _schoolInstructors =>
      _db.collection('school_instructors');
  CollectionReference<Map<String, dynamic>> get _accessRequests =>
      _db.collection('access_requests');
  CollectionReference<Map<String, dynamic>> get _cancellationRequests =>
      _db.collection('cancellation_requests');
  CollectionReference<Map<String, dynamic>> get _instructorNotifications =>
      _db.collection('instructor_notifications');
  CollectionReference<Map<String, dynamic>> get _recurringTemplates =>
      _db.collection('recurring_templates');
  CollectionReference<Map<String, dynamic>> get _competencies =>
      _db.collection('student_competencies');
  CollectionReference<Map<String, dynamic>> get _achievements =>
      _db.collection('student_achievements');
  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection('school_announcements');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

  Stream<School?> streamSchool(String schoolId) {
    return _schools.doc(schoolId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return School.fromDoc(doc);
    });
  }

  Stream<List<SchoolInstructor>> streamSchoolInstructors(String schoolId) {
    return _schoolInstructors
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(SchoolInstructor.fromDoc).toList());
  }

  Stream<SchoolInstructor?> streamInstructorSchoolLink(String instructorId) {
    return _schoolInstructors
        .where('instructorId', isEqualTo: instructorId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SchoolInstructor.fromDoc(snapshot.docs.first);
    });
  }

  /// Check if an owner is also an instructor in their school
  Future<bool> isOwnerAlsoInstructor({
    required String ownerId,
    required String schoolId,
  }) async {
    final snapshot = await _schoolInstructors
        .where('schoolId', isEqualTo: schoolId)
        .where('instructorId', isEqualTo: ownerId)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Check if an instructor owns their school
  Future<bool> doesInstructorOwnSchool({
    required String instructorId,
    required String schoolId,
  }) async {
    final schoolDoc = await _schools.doc(schoolId).get();
    if (!schoolDoc.exists) return false;
    final data = schoolDoc.data();
    return data?['ownerId'] == instructorId;
  }

  Stream<List<AccessRequest>> streamAccessRequestsForInstructor(
    String instructorId,
  ) {
    return _accessRequests
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AccessRequest.fromDoc).toList());
  }

  Stream<List<AccessRequest>> streamAccessRequestsForSchool(String schoolId) {
    return _accessRequests
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AccessRequest.fromDoc).toList());
  }

  Stream<Terms?> streamTermsForSchool(String schoolId) {
    return _terms.doc(schoolId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Terms.fromDoc(doc);
    });
  }

  Future<Terms?> getTermsForSchool(String schoolId) async {
    final doc = await _terms.doc(schoolId).get();
    if (!doc.exists) return null;
    return Terms.fromDoc(doc);
  }

  Future<void> saveSchoolTerms({
    required String schoolId,
    required String text,
  }) {
    final docRef = _terms.doc(schoolId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final currentVersion = (snap.data()?['version'] ?? 0) as int;
      final nextVersion = currentVersion + 1;
      tx.set(docRef, {
        'text': text.trim(),
        'version': nextVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<UserProfile?> streamUserProfileByStudentId(String studentId) {
    return _users
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return UserProfile.fromDoc(snapshot.docs.first);
    });
  }

  Future<UserProfile?> getUserProfileByStudentId(String studentId) async {
    final snapshot = await _users
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return UserProfile.fromDoc(snapshot.docs.first);
  }

  Future<void> createUserProfile(UserProfile profile) {
    return _users.doc(profile.id).set(profile.toMap());
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  Future<String> createSchool({
    required String ownerId,
    required String name,
  }) async {
    final doc = await _schools.add({
      'ownerId': ownerId,
      'name': name,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<String> ensurePersonalSchool({
    required UserProfile instructor,
    String? schoolName,
  }) async {
    if (instructor.schoolId != null && instructor.schoolId!.isNotEmpty) {
      return instructor.schoolId!;
    }
    final finalSchoolName = schoolName ?? '${instructor.name} School';
    final schoolId = await createSchool(
      ownerId: instructor.id,
      name: finalSchoolName,
    );
    await _schoolInstructors.add({
      'schoolId': schoolId,
      'instructorId': instructor.id,
      'feeAmount': 0,
      'feeFrequency': 'week',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await updateUserProfile(instructor.id, {'schoolId': schoolId});
    return schoolId;
  }

  Future<String> addInstructorToSchool({
    required String schoolId,
    required String instructorId,
    required double feeAmount,
    required String feeFrequency,
  }) async {
    final doc = await _schoolInstructors.add({
      'schoolId': schoolId,
      'instructorId': instructorId,
      'feeAmount': feeAmount,
      'feeFrequency': feeFrequency,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateSchoolInstructorFee({
    required String linkId,
    required double feeAmount,
    required String feeFrequency,
  }) {
    return _schoolInstructors.doc(linkId).update({
      'feeAmount': feeAmount,
      'feeFrequency': feeFrequency,
    });
  }

  Future<void> requestAccess({
    required String schoolId,
    required String ownerId,
    required String instructorId,
  }) {
    return _accessRequests.add({
      'schoolId': schoolId,
      'ownerId': ownerId,
      'instructorId': instructorId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToAccessRequest({
    required String requestId,
    required String status,
  }) {
    return _accessRequests.doc(requestId).update({
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Student>> streamStudents(
    String instructorId, {
    String? status,
  }) {
    Query<Map<String, dynamic>> query =
        _students.where('instructorId', isEqualTo: instructorId);
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snapshot) {
      final students = snapshot.docs.map(Student.fromDoc).toList();
      students.sort((a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ));
      return students;
    });
  }

  Stream<Student?> streamStudentById(String studentId) {
    return _students.doc(studentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Student.fromDoc(doc);
    });
  }

  Stream<List<Lesson>> streamLessonsForInstructor(String instructorId) {
    return _lessons
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('startAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Lesson.fromDoc).toList());
  }

  Stream<List<Lesson>> streamLessonsForStudent(String studentId) {
    return _lessons
        .where('studentId', isEqualTo: studentId)
        .orderBy('startAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Lesson.fromDoc).toList());
  }

  Stream<List<Payment>> streamPaymentsForInstructor(String instructorId) {
    return _payments
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Payment.fromDoc).toList());
  }

  Stream<List<Payment>> streamPaymentsForStudent(String studentId) {
    return _payments
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      debugPrint(
        '[payments] studentId=$studentId docs=${snapshot.docs.length}',
      );
      for (final doc in snapshot.docs) {
        debugPrint('[payments] doc=${doc.id} data=${doc.data()}');
      }
      final payments = snapshot.docs.map(Payment.fromDoc).toList();
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return payments;
    });
  }

  /// Payments for a school (payments with schoolId set). Use for school-wide reports.
  Stream<List<Payment>> streamPaymentsForSchool(String schoolId) {
    return _payments
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Payment.fromDoc).toList());
  }

  Future<Student?> getStudentById(String studentId) async {
    final doc = await _students.doc(studentId).get();
    if (!doc.exists) return null;
    return Student.fromDoc(doc);
  }

  Future<String> addStudent(Student student) async {
    final doc = await _students.add(student.toMap());
    return doc.id;
  }

  Future<void> updateStudent(String studentId, Map<String, dynamic> data) {
    return _students.doc(studentId).update(data);
  }

  Future<void> deleteStudent(String studentId) async {
    // Delete student document
    await _students.doc(studentId).delete();
    
    // Also delete the associated user profile if it exists
    // Note: If the student had a login account, the Firebase Auth account will remain
    // but won't be accessible since the user profile is deleted. To fully delete the
    // Auth account, you need to use Firebase Admin SDK via Cloud Functions.
    final userProfile = await getUserProfileByStudentId(studentId);
    if (userProfile != null) {
      // Delete user profile from Firestore
      await _users.doc(userProfile.id).delete();
    }
  }

  Future<void> addPayment({
    required Payment payment,
    required String studentId,
  }) {
    final paymentRef = _payments.doc();
    final studentRef = _students.doc(studentId);
    debugPrint(
      '[addPayment] studentId=$studentId data=${payment.toMap()}',
    );
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
      tx.set(paymentRef, payment.toMap());
      tx.update(studentRef, {
        'balanceHours': current + payment.hoursPurchased,
      });
    });
  }

  Future<void> updatePayment({
    required Payment payment,
    required double previousHours,
  }) {
    final paymentRef = _payments.doc(payment.id);
    final studentRef = _students.doc(payment.studentId);
    final hoursDelta = payment.hoursPurchased - previousHours;
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
      tx.update(paymentRef, {
        'amount': payment.amount,
        'currency': payment.currency,
        'method': payment.method,
        'hoursPurchased': payment.hoursPurchased,
      });
      if (hoursDelta != 0) {
        tx.update(studentRef, {
          'balanceHours': current + hoursDelta,
        });
      }
    });
  }

  Future<void> deletePayment(Payment payment) {
    final paymentRef = _payments.doc(payment.id);
    final studentRef = _students.doc(payment.studentId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
      tx.delete(paymentRef);
      tx.update(studentRef, {
        'balanceHours': current - payment.hoursPurchased,
      });
    });
  }

  Future<void> addLesson({
    required Lesson lesson,
    required String studentId,
  }) {
    final lessonRef = _lessons.doc();
    final studentRef = _students.doc(studentId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      tx.set(lessonRef, lesson.toMap());
      // Only adjust balance if the student still exists
      if (snap.exists) {
        final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
        tx.update(studentRef, {
          'balanceHours': current - lesson.durationHours,
        });
      }
    });
  }

  Future<void> updateLesson({
    required Lesson lesson,
    required double previousDuration,
  }) {
    final lessonRef = _lessons.doc(lesson.id);
    final studentRef = _students.doc(lesson.studentId);
    final durationDelta = lesson.durationHours - previousDuration;
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      tx.update(lessonRef, {
        'startAt': Timestamp.fromDate(lesson.startAt),
        'durationHours': lesson.durationHours,
        'notes': lesson.notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Only adjust balance if the student still exists and duration changed
      if (durationDelta != 0 && snap.exists) {
        final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
        tx.update(studentRef, {
          'balanceHours': current - durationDelta,
        });
      }
    });
  }

  Future<void> deleteLesson(Lesson lesson) {
    final lessonRef = _lessons.doc(lesson.id);
    final studentRef = _students.doc(lesson.studentId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      tx.delete(lessonRef);
      // Only restore balance if the student still exists
      if (snap.exists) {
        final current = (snap.data()?['balanceHours'] ?? 0).toDouble();
        tx.update(studentRef, {
          'balanceHours': current + lesson.durationHours,
        });
      }
    });
  }

  Future<void> updateLessonReflection({
    required String lessonId,
    required String reflection,
  }) {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final trimmed = reflection.trim();
    if (trimmed.isEmpty) {
      data['studentReflection'] = FieldValue.delete();
    } else {
      data['studentReflection'] = trimmed;
    }
    return _lessons.doc(lessonId).update(data);
  }

  Future<String?> findStudentIdByEmail(String email) async {
    final snapshot =
        await _students.where('email', isEqualTo: email).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<String?> findStudentIdByPhone(String phone) async {
    final snapshot =
        await _students.where('phone', isEqualTo: phone).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  // ==================== Cancellation Request Methods ====================

  /// Create a new cancellation request
  Future<String> createCancellationRequest(CancellationRequest request) async {
    final doc = await _cancellationRequests.add(request.toMap());
    return doc.id;
  }

  /// Stream cancellation requests for an instructor
  Stream<List<CancellationRequest>> streamCancellationRequestsForInstructor(
    String instructorId,
  ) {
    return _cancellationRequests
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CancellationRequest.fromDoc).toList());
  }

  /// Stream pending cancellation requests for an instructor
  Stream<List<CancellationRequest>> streamPendingCancellationRequests(
    String instructorId,
  ) {
    return _cancellationRequests
        .where('instructorId', isEqualTo: instructorId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CancellationRequest.fromDoc).toList());
  }

  /// Stream cancellation requests for a student
  Stream<List<CancellationRequest>> streamCancellationRequestsForStudent(
    String studentId,
  ) {
    return _cancellationRequests
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CancellationRequest.fromDoc).toList());
  }

  /// Check if a cancellation request exists for a lesson
  Future<CancellationRequest?> getCancellationRequestForLesson(
    String lessonId,
  ) async {
    final snapshot = await _cancellationRequests
        .where('lessonId', isEqualTo: lessonId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return CancellationRequest.fromDoc(snapshot.docs.first);
  }

  /// Approve a cancellation request
  /// This updates the request status, cancels the lesson, and deducts hours
  Future<void> approveCancellationRequest(CancellationRequest request) {
    final requestRef = _cancellationRequests.doc(request.id);
    final lessonRef = _lessons.doc(request.lessonId);
    final studentRef = _students.doc(request.studentId);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(studentRef);
      final currentBalance = (snap.data()?['balanceHours'] ?? 0).toDouble();

      // Update the cancellation request
      tx.update(requestRef, {
        'status': 'approved',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Update the lesson status to cancelled
      tx.update(lessonRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Deduct hours from student balance (partial refund)
      // If chargePercent is 50%, only 50% of hours are deducted (50% refunded)
      final hoursToDeduct = request.hoursToDeduct * (request.chargePercent / 100);
      tx.update(studentRef, {
        'balanceHours': currentBalance - hoursToDeduct,
      });

      debugPrint(
        '[approveCancellationRequest] Approved request ${request.id}, '
        'deducted $hoursToDeduct hours (${request.chargePercent}% of ${request.hoursToDeduct})',
      );
    });
  }

  /// Decline a cancellation request
  Future<void> declineCancellationRequest(String requestId) {
    return _cancellationRequests.doc(requestId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== Instructor Settings Methods ====================

  /// Update instructor cancellation policy
  Future<void> updateCancellationPolicy({
    required String instructorId,
    required int windowHours,
    required int chargePercent,
  }) {
    return _users.doc(instructorId).update({
      'cancellationPolicy': {
        'windowHours': windowHours,
        'chargePercent': chargePercent,
      },
    });
  }

  /// Update instructor reminder hours
  Future<void> updateReminderHours({
    required String instructorId,
    required int reminderHoursBefore,
  }) {
    return _users.doc(instructorId).update({
      'reminderHoursBefore': reminderHoursBefore,
    });
  }

  /// Update all instructor notification settings
  Future<void> updateInstructorSettings({
    required String instructorId,
    int? windowHours,
    int? chargePercent,
    int? reminderHoursBefore,
  }) {
    final data = <String, dynamic>{};

    if (windowHours != null || chargePercent != null) {
      data['cancellationPolicy'] = {
        if (windowHours != null) 'windowHours': windowHours,
        if (chargePercent != null) 'chargePercent': chargePercent,
      };
    }

    if (reminderHoursBefore != null) {
      data['reminderHoursBefore'] = reminderHoursBefore;
    }

    if (data.isEmpty) return Future.value();
    return _users.doc(instructorId).update(data);
  }

  /// Update lesson status
  Future<void> updateLessonStatus({
    required String lessonId,
    required String status,
  }) {
    return _lessons.doc(lessonId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update test result for a lesson
  Future<void> updateLessonTestResult({
    required String lessonId,
    required String? testResult,
  }) {
    return _lessons.doc(lessonId).update({
      'testResult': testResult,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send instructor notification to student
  /// Creates a document that triggers a Cloud Function to send the notification
  Future<void> sendInstructorNotification({
    required String instructorId,
    required String studentId,
    required String lessonId,
    required String notificationType, // 'on_way' or 'arrived'
  }) async {
    try {
      debugPrint('[Notification] Creating instructor notification document...');
      debugPrint('[Notification] instructorId: $instructorId');
      debugPrint('[Notification] studentId: $studentId');
      debugPrint('[Notification] lessonId: $lessonId');
      debugPrint('[Notification] notificationType: $notificationType');
      
      final docRef = await _instructorNotifications.add({
        'instructorId': instructorId,
        'studentId': studentId,
        'lessonId': lessonId,
        'notificationType': notificationType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[Notification] Document created with ID: ${docRef.id}');
      debugPrint('[Notification] Cloud Function should trigger automatically');
    } catch (e) {
      debugPrint('[Notification] Error creating notification document: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECURRING TEMPLATES (Feature 2.4)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> saveRecurringTemplate(RecurringTemplate template) async {
    final docRef = await _recurringTemplates.add(template.toMap());
    return docRef.id;
  }

  Stream<List<RecurringTemplate>> streamRecurringTemplates(String instructorId) {
    return _recurringTemplates
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(RecurringTemplate.fromDoc).toList());
  }

  Future<void> deleteRecurringTemplate(String id) {
    return _recurringTemplates.doc(id).delete();
  }

  /// Batch-create lessons from a recurring template
  Future<int> generateLessonsFromTemplate({
    required RecurringTemplate template,
    required DateTime startFromDate,
  }) async {
    final batch = _db.batch();
    int count = 0;

    // Find the first occurrence of the desired dayOfWeek on or after startFromDate
    var current = startFromDate;
    while (current.weekday != template.dayOfWeek) {
      current = current.add(const Duration(days: 1));
    }

    for (int week = 0; week < template.weeks; week++) {
      final lessonDate = current.add(Duration(days: week * 7));
      final startAt = DateTime(
        lessonDate.year,
        lessonDate.month,
        lessonDate.day,
        template.startHour,
        template.startMinute,
      );

      final lessonRef = _lessons.doc();
      batch.set(lessonRef, {
        'instructorId': template.instructorId,
        'studentId': template.studentId,
        'startAt': Timestamp.fromDate(startAt),
        'durationHours': template.durationHours,
        'lessonType': template.lessonType,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      count++;
    }

    await batch.commit();
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPETENCIES / PROGRESS TRACKING (Feature 2.6)
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Competency>> streamCompetencies({
    required String studentId,
    required String instructorId,
  }) {
    return _competencies
        .where('studentId', isEqualTo: studentId)
        .where('instructorId', isEqualTo: instructorId)
        .snapshots()
        .map((snap) => snap.docs.map(Competency.fromDoc).toList());
  }

  Future<void> upsertCompetency(Competency competency) async {
    // Check if a competency already exists for this skill
    final existing = await _competencies
        .where('studentId', isEqualTo: competency.studentId)
        .where('instructorId', isEqualTo: competency.instructorId)
        .where('skill', isEqualTo: competency.skill)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await _competencies.doc(existing.docs.first.id).update(competency.toMap());
    } else {
      await _competencies.add(competency.toMap());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACHIEVEMENTS (Feature 2.7)
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Achievement>> streamAchievements(String studentId) {
    return _achievements
        .where('studentId', isEqualTo: studentId)
        .orderBy('awardedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Achievement.fromDoc).toList());
  }

  Future<void> awardAchievement(Achievement achievement) async {
    // Check if already awarded
    final existing = await _achievements
        .where('studentId', isEqualTo: achievement.studentId)
        .where('type', isEqualTo: achievement.type)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _achievements.add(achievement.toMap());
    }
  }

  /// Check and award achievements based on cumulative hours
  Future<void> checkAndAwardAchievements({
    required String studentId,
    required double totalHours,
    required int totalLessons,
  }) async {
    if (totalLessons >= 1) {
      await awardAchievement(Achievement(
        id: '',
        studentId: studentId,
        type: 'first_lesson',
        title: 'First Steps',
        description: 'Completed your first driving lesson',
      ));
    }
    if (totalHours >= 5) {
      await awardAchievement(Achievement(
        id: '',
        studentId: studentId,
        type: '5_hours',
        title: '5 Hour Club',
        description: 'Completed 5 hours of driving lessons',
      ));
    }
    if (totalHours >= 10) {
      await awardAchievement(Achievement(
        id: '',
        studentId: studentId,
        type: '10_hours',
        title: 'Road Regular',
        description: 'Completed 10 hours of driving lessons',
      ));
    }
    if (totalHours >= 20) {
      await awardAchievement(Achievement(
        id: '',
        studentId: studentId,
        type: '20_hours',
        title: 'Road Warrior',
        description: 'Completed 20 hours of driving lessons',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANNOUNCEMENTS (Feature 2.9)
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Announcement>> streamAnnouncementsForSchool(String schoolId) {
    return _announcements
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Announcement.fromDoc).toList());
  }

  Stream<List<Announcement>> streamAnnouncementsForAudience({
    required String schoolId,
    required String role,
  }) {
    // Return announcements matching 'all' or the specific role
    return _announcements
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(Announcement.fromDoc)
            .where((a) => a.audience == 'all' || a.audience == '${role}s')
            .toList());
  }

  Future<String> createAnnouncement(Announcement announcement) async {
    final docRef = await _announcements.add(announcement.toMap());
    return docRef.id;
  }

  Future<void> deleteAnnouncement(String id) {
    return _announcements.doc(id).delete();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPENSES
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Expense>> streamExpensesForSchool(String schoolId) {
    return _expenses
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  Stream<List<Expense>> streamExpensesForInstructor(String instructorId) {
    return _expenses
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  Future<String> addExpense(Expense expense) async {
    final doc = await _expenses.add(expense.toMap());
    return doc.id;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) {
    return _expenses.doc(id).update(data);
  }

  Future<void> deleteExpense(String id) {
    return _expenses.doc(id).delete();
  }

  Future<int> batchAddExpenses(List<Expense> expenses) async {
    int count = 0;
    // Firestore batch limit is 500 operations
    for (var i = 0; i < expenses.length; i += 500) {
      final batch = _db.batch();
      final chunk = expenses.skip(i).take(500);
      for (final expense in chunk) {
        final ref = _expenses.doc();
        batch.set(ref, expense.toMap());
        count++;
      }
      await batch.commit();
    }
    return count;
  }
}
