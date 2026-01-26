import 'package:cloud_firestore/cloud_firestore.dart';

import 'cancellation_rule.dart';

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

class InstructorSettings {
  InstructorSettings({
    this.cancellationRules,
    this.reminderHoursBefore,
    this.notificationSettings,
    this.defaultNavigationApp,
  });

  final List<CancellationRule>? cancellationRules;
  final int? reminderHoursBefore;
  final Map<String, bool>? notificationSettings; // e.g., {'autoSendOnWay': true, 'autoSendArrived': false}
  final String? defaultNavigationApp; // 'google_maps', 'apple_maps', or null for system default

  Map<String, dynamic> toMap() {
    return {
      if (cancellationRules != null)
        'cancellationRules': cancellationRules!.map((r) => r.toMap()).toList(),
      if (reminderHoursBefore != null) 'reminderHoursBefore': reminderHoursBefore,
      if (notificationSettings != null) 'notificationSettings': notificationSettings,
      if (defaultNavigationApp != null) 'defaultNavigationApp': defaultNavigationApp,
    };
  }

  static InstructorSettings fromMap(Map<String, dynamic>? data) {
    if (data == null) return InstructorSettings();
    return InstructorSettings(
      cancellationRules: data['cancellationRules'] != null
          ? (data['cancellationRules'] as List)
              .map((r) => CancellationRule.fromMap(r as Map<String, dynamic>))
              .toList()
          : null,
      reminderHoursBefore: data['reminderHoursBefore'] as int?,
      notificationSettings: data['notificationSettings'] != null
          ? Map<String, bool>.from(data['notificationSettings'] as Map)
          : null,
      defaultNavigationApp: data['defaultNavigationApp'] as String?,
    );
  }

  InstructorSettings copyWith({
    List<CancellationRule>? cancellationRules,
    int? reminderHoursBefore,
    Map<String, bool>? notificationSettings,
    String? defaultNavigationApp,
  }) {
    return InstructorSettings(
      cancellationRules: cancellationRules ?? this.cancellationRules,
      reminderHoursBefore: reminderHoursBefore ?? this.reminderHoursBefore,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      defaultNavigationApp: defaultNavigationApp ?? this.defaultNavigationApp,
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
    this.cancellationPolicy, // Legacy field, kept for backward compatibility
    this.reminderHoursBefore, // Legacy field
    this.instructorSettings, // New extensible settings
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
  final CancellationPolicy? cancellationPolicy; // Legacy - use instructorSettings.cancellationRules instead
  final int? reminderHoursBefore; // Legacy - use instructorSettings.reminderHoursBefore instead
  final InstructorSettings? instructorSettings;

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
      // Legacy fields (kept for backward compatibility)
      if (cancellationPolicy != null)
        'cancellationPolicy': cancellationPolicy!.toMap(),
      if (reminderHoursBefore != null)
        'reminderHoursBefore': reminderHoursBefore,
      // New extensible settings
      if (instructorSettings != null)
        'instructorSettings': instructorSettings!.toMap(),
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
      // Legacy fields (for backward compatibility)
      cancellationPolicy: data['cancellationPolicy'] != null
          ? CancellationPolicy.fromMap(
              data['cancellationPolicy'] as Map<String, dynamic>)
          : null,
      reminderHoursBefore: data['reminderHoursBefore'] as int?,
      // New extensible settings
      instructorSettings: data['instructorSettings'] != null
          ? InstructorSettings.fromMap(
              data['instructorSettings'] as Map<String, dynamic>)
          : null,
    );
  }

  // Helper to get cancellation rules (from new settings or legacy policy)
  List<CancellationRule> getCancellationRules() {
    if (instructorSettings?.cancellationRules != null) {
      return instructorSettings!.cancellationRules!;
    }
    // Fallback to legacy policy
    if (cancellationPolicy != null) {
      return [
        CancellationRule(
          hoursBefore: cancellationPolicy!.windowHours,
          chargePercent: cancellationPolicy!.chargePercent,
        ),
      ];
    }
    // Default rule
    return [
      CancellationRule(hoursBefore: 24, chargePercent: 50),
    ];
  }

  // Helper to get reminder hours (from new settings or legacy field)
  int getReminderHours() {
    return instructorSettings?.reminderHoursBefore ??
        reminderHoursBefore ??
        24;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
