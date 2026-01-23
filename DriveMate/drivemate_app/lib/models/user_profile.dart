import 'package:cloud_firestore/cloud_firestore.dart';

class CancellationPolicy {
  CancellationPolicy({
    required this.windowHours,
    required this.chargePercent,
  });

  final int windowHours;
  final int chargePercent;

  Map<String, dynamic> toMap() {
    return {
      'windowHours': windowHours,
      'chargePercent': chargePercent,
    };
  }

  static CancellationPolicy fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return CancellationPolicy(windowHours: 24, chargePercent: 50);
    }
    return CancellationPolicy(
      windowHours: (data['windowHours'] as int?) ?? 24,
      chargePercent: (data['chargePercent'] as int?) ?? 50,
    );
  }

  CancellationPolicy copyWith({int? windowHours, int? chargePercent}) {
    return CancellationPolicy(
      windowHours: windowHours ?? this.windowHours,
      chargePercent: chargePercent ?? this.chargePercent,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.schoolId,
    this.studentId,
    this.acceptedTermsVersion,
    this.acceptedTermsAt,
    this.fcmToken,
    this.cancellationPolicy,
    this.reminderHoursBefore,
  });

  final String id;
  final String role;
  final String name;
  final String email;
  final String? schoolId;
  final String? studentId;
  final int? acceptedTermsVersion;
  final DateTime? acceptedTermsAt;
  final String? fcmToken;
  final CancellationPolicy? cancellationPolicy;
  final int? reminderHoursBefore;

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
      'schoolId': schoolId,
      'studentId': studentId,
      if (acceptedTermsVersion != null)
        'acceptedTermsVersion': acceptedTermsVersion,
      if (acceptedTermsAt != null)
        'acceptedTermsAt': Timestamp.fromDate(acceptedTermsAt!),
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (cancellationPolicy != null)
        'cancellationPolicy': cancellationPolicy!.toMap(),
      if (reminderHoursBefore != null)
        'reminderHoursBefore': reminderHoursBefore,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static UserProfile fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return UserProfile(
      id: doc.id,
      role: (data['role'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      schoolId: data['schoolId'] as String?,
      studentId: data['studentId'] as String?,
      acceptedTermsVersion: (data['acceptedTermsVersion'] as int?),
      acceptedTermsAt: _toDateTime(data['acceptedTermsAt']),
      fcmToken: data['fcmToken'] as String?,
      cancellationPolicy: data['cancellationPolicy'] != null
          ? CancellationPolicy.fromMap(
              data['cancellationPolicy'] as Map<String, dynamic>)
          : null,
      reminderHoursBefore: data['reminderHoursBefore'] as int?,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
