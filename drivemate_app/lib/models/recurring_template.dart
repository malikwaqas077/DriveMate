import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTemplate {
  RecurringTemplate({
    required this.id,
    required this.instructorId,
    required this.studentId,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.durationHours,
    this.lessonType = 'lesson',
    required this.repeatCount,
    this.frequency = 'weekly',
    this.createdAt,
  });

  final String id;
  final String instructorId;
  final String studentId;
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final int startHour;
  final int startMinute;
  final double durationHours;
  final String lessonType;
  final int repeatCount; // Number of lessons to generate
  final String frequency; // 'daily', 'everyOtherDay', 'weekly', 'biweekly'
  final DateTime? createdAt;

  /// Number of days between each lesson for this frequency
  int get daysBetween {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'everyOtherDay':
        return 2;
      case 'biweekly':
        return 14;
      case 'weekly':
      default:
        return 7;
    }
  }

  static const frequencyLabels = {
    'daily': 'Daily',
    'everyOtherDay': 'Every other day',
    'weekly': 'Weekly',
    'biweekly': 'Every 2 weeks',
  };

  String get frequencyLabel => frequencyLabels[frequency] ?? 'Weekly';

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'studentId': studentId,
      'dayOfWeek': dayOfWeek,
      'startHour': startHour,
      'startMinute': startMinute,
      'durationHours': durationHours,
      'lessonType': lessonType,
      'repeatCount': repeatCount,
      'frequency': frequency,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static RecurringTemplate fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Support legacy 'weeks' field
    final repeatCount = (data['repeatCount'] as int?) ??
        (data['weeks'] as int?) ??
        4;
    return RecurringTemplate(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      dayOfWeek: (data['dayOfWeek'] as int?) ?? 1,
      startHour: (data['startHour'] as int?) ?? 9,
      startMinute: (data['startMinute'] as int?) ?? 0,
      durationHours: _toDouble(data['durationHours']),
      lessonType: (data['lessonType'] ?? 'lesson') as String,
      repeatCount: repeatCount,
      frequency: (data['frequency'] ?? 'weekly') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 1.0;
  }
}
