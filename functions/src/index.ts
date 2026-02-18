import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Helper function to send push notification
async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: { [key: string]: string | number | boolean },
  isChatMessage: boolean = false
): Promise<void> {
  try {
    // Convert all data values to strings (FCM requirement)
    const stringData: { [key: string]: string } = {};
    if (data) {
      for (const [key, value] of Object.entries(data)) {
        stringData[key] = String(value);
      }
    }

    // For chat messages, send data-only to prevent FCM from auto-displaying notifications
    // The Flutter app will show the notification with actions using flutter_local_notifications
    const message: any = isChatMessage
      ? {
          // Data-only message - no notification field at all
          token: fcmToken,
          data: {
            ...stringData,
            title,
            body,
          },
          android: {
            // Data-only - no notification field, just priority
            priority: "high" as const,
          },
          apns: {
            payload: {
              aps: {
                // Data-only - contentAvailable tells iOS to wake app
                contentAvailable: true,
              },
            },
          },
        }
      : {
          // Regular notification message
          token: fcmToken,
          notification: {
            title,
            body,
          },
          data: stringData,
          android: {
            notification: {
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              channelId: "default",
              priority: "high" as const,
              visibility: "public" as const,
              defaultSound: true,
              defaultVibrateTimings: true,
            },
            priority: "high" as const,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                alert: {
                  title,
                  body,
                },
                badge: 1,
              },
            },
          },
        };

    // Note: Notification actions are handled in Flutter app using flutter_local_notifications

    await messaging.send(message);
    functions.logger.info(`Push sent: ${title} to token ${fcmToken.slice(0, 10)}...`);
  } catch (error) {
    functions.logger.error("Error sending push notification:", error);
  }
}

// Helper to get user FCM token
async function getUserFcmToken(userId: string): Promise<string | null> {
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) return null;
  return userDoc.data()?.fcmToken || null;
}

// Helper to get student name
async function getStudentName(studentId: string): Promise<string> {
  const studentDoc = await db.collection("students").doc(studentId).get();
  if (!studentDoc.exists) return "Student";
  return studentDoc.data()?.name || "Student";
}

/**
 * Triggered when a new lesson is created
 * Sends push notification to the student
 */
export const onLessonCreated = functions.firestore
  .document("lessons/{lessonId}")
  .onCreate(async (snapshot, context) => {
    const lesson = snapshot.data();
    const studentId = lesson.studentId;

    if (!studentId) {
      functions.logger.warn("Lesson created without studentId");
      return;
    }

    // Get the user profile linked to this student
    const userQuery = await db
      .collection("users")
      .where("studentId", "==", studentId)
      .limit(1)
      .get();

    if (userQuery.empty) {
      functions.logger.info(`No user found for student ${studentId}`);
      return;
    }

    const userDoc = userQuery.docs[0];
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) {
      functions.logger.info(`No FCM token for user ${userDoc.id}`);
      return;
    }

    // Format the lesson date and time
    const startAt = lesson.startAt?.toDate();
    if (!startAt) return;

    const dateFormatter = new Intl.DateTimeFormat("en-GB", {
      weekday: "long",
      day: "numeric",
      month: "long",
    });
    const timeFormatter = new Intl.DateTimeFormat("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });

    const dateStr = dateFormatter.format(startAt);
    const timeStr = timeFormatter.format(startAt);

    await sendPushNotification(
      fcmToken,
      "New Lesson Scheduled",
      `You have a new lesson on ${dateStr} at ${timeStr}`,
      {
        type: "lesson_created",
        lessonId: context.params.lessonId,
      }
    );
  });

/**
 * Triggered when a lesson's studentReflection is updated
 * Sends push notification to the instructor
 */
export const onReflectionAdded = functions.firestore
  .document("lessons/{lessonId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if reflection was added/updated
    const hadReflection = before.studentReflection && before.studentReflection.trim();
    const hasReflection = after.studentReflection && after.studentReflection.trim();

    if (!hasReflection || (hadReflection && before.studentReflection === after.studentReflection)) {
      return; // No new reflection
    }

    const instructorId = after.instructorId;
    const studentId = after.studentId;

    if (!instructorId) return;

    const fcmToken = await getUserFcmToken(instructorId);
    if (!fcmToken) {
      functions.logger.info(`No FCM token for instructor ${instructorId}`);
      return;
    }

    const studentName = await getStudentName(studentId);

    await sendPushNotification(
      fcmToken,
      "New Lesson Reflection",
      `${studentName} added a reflection for their lesson`,
      {
        type: "reflection_added",
        lessonId: context.params.lessonId,
        studentId: studentId,
      }
    );
  });

/**
 * Triggered when a cancellation request is created
 * Sends push notification to the instructor
 */
export const onCancellationRequestCreated = functions.firestore
  .document("cancellation_requests/{requestId}")
  .onCreate(async (snapshot, context) => {
    const request = snapshot.data();
    const instructorId = request.instructorId;
    const studentId = request.studentId;
    const lessonStartAt = request.lessonStartAt?.toDate();

    if (!instructorId) return;

    const fcmToken = await getUserFcmToken(instructorId);
    if (!fcmToken) {
      functions.logger.info(`No FCM token for instructor ${instructorId}`);
      return;
    }

    const studentName = await getStudentName(studentId);

    let dateStr = "";
    if (lessonStartAt) {
      const dateFormatter = new Intl.DateTimeFormat("en-GB", {
        weekday: "long",
        day: "numeric",
        month: "long",
      });
      dateStr = ` on ${dateFormatter.format(lessonStartAt)}`;
    }

    await sendPushNotification(
      fcmToken,
      "Cancellation Request",
      `${studentName} requested to cancel a lesson${dateStr}`,
      {
        type: "cancellation_request",
        requestId: context.params.requestId,
        studentId: studentId,
      }
    );
  });

/**
 * Triggered when a cancellation request status changes
 * Sends push notification to the student
 */
export const onCancellationRequestResponded = functions.firestore
  .document("cancellation_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger if status changed from 'pending'
    if (before.status !== "pending" || after.status === "pending") {
      return;
    }

    const studentId = after.studentId;

    // Get the user profile linked to this student
    const userQuery = await db
      .collection("users")
      .where("studentId", "==", studentId)
      .limit(1)
      .get();

    if (userQuery.empty) {
      functions.logger.info(`No user found for student ${studentId}`);
      return;
    }

    const userDoc = userQuery.docs[0];
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) {
      functions.logger.info(`No FCM token for user ${userDoc.id}`);
      return;
    }

    const isApproved = after.status === "approved";
    const title = isApproved ? "Cancellation Approved" : "Cancellation Declined";
    const body = isApproved
      ? "Your lesson cancellation has been approved"
      : "Your lesson cancellation request was declined";

    await sendPushNotification(
      fcmToken,
      title,
      body,
      {
        type: "cancellation_response",
        requestId: context.params.requestId,
        status: after.status,
      }
    );
  });

/**
 * Scheduled function to send lesson reminders
 * Runs every hour and sends reminders for upcoming lessons
 */
export const scheduleLessonReminders = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async () => {
    const now = new Date();
    functions.logger.info(`Running lesson reminders at ${now.toISOString()}`);

    // Get all lessons in the next 24 hours that haven't been cancelled
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const lessonsQuery = await db
      .collection("lessons")
      .where("startAt", ">=", admin.firestore.Timestamp.fromDate(now))
      .where("startAt", "<=", admin.firestore.Timestamp.fromDate(tomorrow))
      .where("status", "in", ["scheduled", null])
      .get();

    functions.logger.info(`Found ${lessonsQuery.size} upcoming lessons`);

    const processedStudents = new Set<string>();

    for (const lessonDoc of lessonsQuery.docs) {
      const lesson = lessonDoc.data();
      const studentId = lesson.studentId;
      const instructorId = lesson.instructorId;
      const startAt = lesson.startAt?.toDate();

      if (!studentId || !instructorId || !startAt) continue;
      if (processedStudents.has(studentId)) continue; // One reminder per student per run

      // Get instructor's reminder settings
      const instructorDoc = await db.collection("users").doc(instructorId).get();
      if (!instructorDoc.exists) continue;

      const reminderHoursBefore = instructorDoc.data()?.reminderHoursBefore || 24;
      const hoursUntilLesson = (startAt.getTime() - now.getTime()) / (1000 * 60 * 60);

      // Check if it's time to send reminder (within the reminder window and before next hour)
      if (hoursUntilLesson > reminderHoursBefore || hoursUntilLesson < reminderHoursBefore - 1) {
        continue;
      }

      // Get student's user profile for FCM token
      const userQuery = await db
        .collection("users")
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

      if (userQuery.empty) continue;

      const userDoc = userQuery.docs[0];
      const fcmToken = userDoc.data().fcmToken;

      if (!fcmToken) continue;

      // Format the lesson time
      const timeFormatter = new Intl.DateTimeFormat("en-GB", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      const dateFormatter = new Intl.DateTimeFormat("en-GB", {
        weekday: "long",
      });

      const dayStr = dateFormatter.format(startAt);
      const timeStr = timeFormatter.format(startAt);

      let reminderText = "";
      if (hoursUntilLesson < 2) {
        reminderText = `Your lesson is starting soon at ${timeStr}`;
      } else if (hoursUntilLesson < 12) {
        reminderText = `Don't forget your lesson ${dayStr.toLowerCase() === new Intl.DateTimeFormat("en-GB", { weekday: "long" }).format(now).toLowerCase() ? "today" : "tomorrow"} at ${timeStr}`;
      } else {
        reminderText = `Reminder: You have a lesson ${dayStr.toLowerCase() === new Intl.DateTimeFormat("en-GB", { weekday: "long" }).format(now).toLowerCase() ? "today" : dayStr} at ${timeStr}`;
      }

      await sendPushNotification(
        fcmToken,
        "Lesson Reminder",
        reminderText,
        {
          type: "lesson_reminder",
          lessonId: lessonDoc.id,
        }
      );

      processedStudents.add(studentId);
      functions.logger.info(`Sent reminder to student ${studentId} for lesson at ${startAt.toISOString()}`);
    }

    functions.logger.info(`Sent ${processedStudents.size} lesson reminders`);
  });

// Helper to get instructor name
async function getInstructorName(instructorId: string): Promise<string> {
  const instructorDoc = await db.collection("users").doc(instructorId).get();
  if (!instructorDoc.exists) return "Your instructor";
  return instructorDoc.data()?.name || "Your instructor";
}

/**
 * Triggered when an instructor notification is created
 * Sends push notification to the student
 */
export const onInstructorNotificationCreated = functions.firestore
  .document("instructor_notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const notificationId = context.params.notificationId;

    const instructorId = data.instructorId;
    const studentId = data.studentId;
    const lessonId = data.lessonId;
    const notificationType = data.notificationType; // 'on_way' or 'arrived'

    if (!instructorId || !studentId || !lessonId || !notificationType) {
      functions.logger.error(`Invalid notification data: ${JSON.stringify(data)}`);
      return;
    }

    // Get student's user profile for FCM token
    const userQuery = await db
      .collection("users")
      .where("studentId", "==", studentId)
      .limit(1)
      .get();

    if (userQuery.empty) {
      functions.logger.info(`No user profile found for student ${studentId}`);
      await db.collection("instructor_notifications").doc(notificationId).delete();
      return;
    }

    const userDoc = userQuery.docs[0];
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) {
      functions.logger.info(`No FCM token for student ${studentId}`);
      await db.collection("instructor_notifications").doc(notificationId).delete();
      return;
    }

    // Get instructor name
    const instructorName = await getInstructorName(instructorId);

    // Set notification title and body based on type
    let title = "";
    let body = "";

    if (notificationType === "on_way") {
      title = "Instructor On Way";
      body = `${instructorName} is on their way to you`;
    } else if (notificationType === "arrived") {
      title = "Instructor Arrived";
      body = `${instructorName} has arrived`;
    } else {
      functions.logger.error(`Unknown notification type: ${notificationType}`);
      await db.collection("instructor_notifications").doc(notificationId).delete();
      return;
    }

    // Send notification
    await sendPushNotification(
      fcmToken,
      title,
      body,
      {
        type: "instructor_notification",
        notificationType: notificationType,
        lessonId: lessonId,
        instructorId: instructorId,
      }
    );

    // Delete the notification document after sending
    await db.collection("instructor_notifications").doc(notificationId).delete();

    functions.logger.info(
      `Sent ${notificationType} notification to student ${studentId} from instructor ${instructorId}`
    );
  });

/**
 * Triggered when a new message is created in a conversation
 * Sends push notification to the recipient
 */
export const onMessageCreated = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const conversationId = context.params.conversationId;
    const senderId = message.senderId;
    const senderRole = message.senderRole;
    const messageText = message.text || "";

    if (!senderId || !senderRole || !conversationId) {
      functions.logger.warn("Message created with missing data");
      return;
    }

    // Get conversation to find recipient
    const conversationDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    if (!conversationDoc.exists) {
      functions.logger.warn(`Conversation ${conversationId} not found`);
      return;
    }

    const conversation = conversationDoc.data()!;
    const instructorId = conversation.instructorId;
    const studentId = conversation.studentId;

    // Determine recipient
    let recipientId: string | null = null;

    if (senderRole === "instructor") {
      // Instructor sent message, notify student
      recipientId = studentId;
    } else {
      // Student sent message, notify instructor
      recipientId = instructorId;
    }

    if (!recipientId) {
      functions.logger.warn(`No recipient found for conversation ${conversationId}`);
      return;
    }

    // Get recipient's FCM token
    let fcmToken: string | null = null;

    if (senderRole === "instructor") {
      // Student is recipient - find user profile by studentId
      const userQuery = await db
        .collection("users")
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

      if (!userQuery.empty) {
        fcmToken = userQuery.docs[0].data()?.fcmToken || null;
      }
    } else {
      // Instructor is recipient - get directly by userId
      fcmToken = await getUserFcmToken(instructorId);
    }

    if (!fcmToken) {
      functions.logger.info(`No FCM token for recipient ${recipientId}`);
      return;
    }

    // Get sender name
    let senderName = "";
    if (senderRole === "instructor") {
      senderName = await getInstructorName(senderId);
    } else {
      senderName = await getStudentName(senderId);
    }

    // Truncate message text for notification
    const truncatedText =
      messageText.length > 100
        ? messageText.substring(0, 100) + "..."
        : messageText;

    await sendPushNotification(
      fcmToken,
      senderName,
      truncatedText,
      {
        type: "chat_message",
        conversationId: conversationId,
        messageId: context.params.messageId,
        senderId: senderId,
        senderRole: senderRole,
      },
      true // isChatMessage = true for heads-up and actions
    );

    functions.logger.info(
      `Sent chat notification to ${recipientId} from ${senderId} in conversation ${conversationId}`
    );
  });

/**
 * Triggered when a new announcement is created
 * Sends push notification to all users in the school matching the audience
 */
export const onAnnouncementCreated = functions.firestore
  .document("school_announcements/{announcementId}")
  .onCreate(async (snapshot, context) => {
    const announcement = snapshot.data();
    const schoolId = announcement.schoolId;
    const audience = announcement.audience || "all"; // 'all', 'instructors', 'students'
    const title = announcement.title || "New Announcement";
    const body = announcement.body || "";

    if (!schoolId) {
      functions.logger.warn("Announcement created without schoolId");
      return;
    }

    functions.logger.info(
      `New announcement "${title}" for school ${schoolId}, audience: ${audience}`
    );

    // Query all users in this school
    let usersQuery = db
      .collection("users")
      .where("schoolId", "==", schoolId);

    const usersSnapshot = await usersQuery.get();

    if (usersSnapshot.empty) {
      functions.logger.info(`No users found for school ${schoolId}`);
      return;
    }

    let sentCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      const userRole = userData.role;

      // Skip users without FCM token
      if (!fcmToken) continue;

      // Skip the author of the announcement
      if (userDoc.id === announcement.authorId) continue;

      // Check audience filter
      if (audience === "instructors" && userRole !== "instructor") continue;
      if (audience === "students" && userRole !== "student") continue;

      // Send notification
      try {
        await sendPushNotification(
          fcmToken,
          title,
          body.length > 150 ? body.substring(0, 150) + "..." : body,
          {
            type: "announcement",
            announcementId: context.params.announcementId,
            schoolId: schoolId,
          }
        );
        sentCount++;
      } catch (error) {
        functions.logger.error(
          `Failed to send announcement to user ${userDoc.id}:`,
          error
        );
      }
    }

    functions.logger.info(
      `Sent announcement "${title}" to ${sentCount} users in school ${schoolId}`
    );
  });
