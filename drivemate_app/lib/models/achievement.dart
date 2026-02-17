import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  Achievement({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.description,
    this.awardedAt,
  });

  final String id;
  final String studentId;
  final String type;
  final String title;
  final String description;
  final DateTime? awardedAt;

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'type': type,
      'title': title,
      'description': description,
      'awardedAt': FieldValue.serverTimestamp(),
    };
  }

  static Achievement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Achievement(
      id: doc.id,
      studentId: (data['studentId'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      awardedAt: (data['awardedAt'] as Timestamp?)?.toDate(),
    );
  }

  static const Map<String, AchievementDefinition> definitions = {
    'first_lesson': AchievementDefinition(
      type: 'first_lesson',
      title: 'First Steps',
      description: 'Completed your first driving lesson',
      icon: 'ðŸš—',
    ),
    '5_hours': AchievementDefinition(
      type: '5_hours',
      title: '5 Hour Club',
      description: 'Completed 5 hours of driving lessons',
      icon: 'â­',
    ),
    '10_hours': AchievementDefinition(
      type: '10_hours',
      title: 'Road Regular',
      description: 'Completed 10 hours of driving lessons',
      icon: 'ðŸŒŸ',
    ),
    '20_hours': AchievementDefinition(
      type: '20_hours',
      title: 'Road Warrior',
      description: 'Completed 20 hours of driving lessons',
      icon: 'ðŸ†',
    ),
    'mock_test_completed': AchievementDefinition(
      type: 'mock_test_completed',
      title: 'Test Ready',
      description: 'Completed a mock driving test',
      icon: 'ðŸ“‹',
    ),
    'test_day': AchievementDefinition(
      type: 'test_day',
      title: 'The Big Day',
      description: 'Scheduled your driving test',
      icon: 'ðŸŽ¯',
    ),
  };
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String type;
  final String title;
  final String description;
  final String icon;
}
