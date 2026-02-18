import 'package:cloud_firestore/cloud_firestore.dart';

class Competency {
  Competency({
    required this.id,
    required this.studentId,
    required this.instructorId,
    required this.skill,
    required this.rating,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String instructorId;
  final String skill;
  final int rating; // 1-5
  final String? notes;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'instructorId': instructorId,
      'skill': skill,
      'rating': rating,
      if (notes != null) 'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Competency fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Competency(
      id: doc.id,
      studentId: (data['studentId'] ?? '') as String,
      instructorId: (data['instructorId'] ?? '') as String,
      skill: (data['skill'] ?? '') as String,
      rating: (data['rating'] as int?) ?? 0,
      notes: data['notes'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Competency copyWith({int? rating, String? notes}) {
    return Competency(
      id: id,
      studentId: studentId,
      instructorId: instructorId,
      skill: skill,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      updatedAt: updatedAt,
    );
  }

  /// DVSA 5-level progression scale labels
  static const List<String> ratingLabels = [
    'Not started',
    'Introduced',
    'Directed',
    'Prompted',
    'Rarely prompted',
    'Independent',
  ];

  static String ratingLabel(int rating) {
    if (rating < 0 || rating >= ratingLabels.length) return ratingLabels[0];
    return ratingLabels[rating];
  }

  /// All skills in a flat list (for backward compat)
  static List<String> get predefinedSkills =>
      skillSections.expand((s) => s.skills).toList();

  /// DVSA-based structured competency sections, ordered by learning progression
  static const List<SkillSection> skillSections = [
    // Section 1 - Pre-driving foundation
    SkillSection(
      title: 'The Basics',
      icon: 'directions_car',
      skills: [
        'Legal responsibilities',
        'Vehicle safety checks (Show Me/Tell Me)',
        'Cockpit drill (DSSSM)',
      ],
    ),
    // Section 2 - Core vehicle handling
    SkillSection(
      title: 'Vehicle Control',
      icon: 'settings',
      skills: [
        'Controls and instruments',
        'Moving off and stopping',
        'Clutch control',
        'Gear selection and changing',
        'Steering control',
        'Safe positioning on road',
      ],
    ),
    // Section 3 - Awareness & communication
    SkillSection(
      title: 'Observations & Signals',
      icon: 'visibility',
      skills: [
        'Mirrors - vision and use (MSM)',
        'Signals - indicating correctly',
        'Anticipation and planning',
        'Use of speed',
        'Following distance',
        'Awareness of other traffic',
      ],
    ),
    // Section 4 - Core road navigation
    SkillSection(
      title: 'Junctions & Roundabouts',
      icon: 'turn_right',
      skills: [
        'Junctions - approach and observation',
        'Junctions - turning left',
        'Junctions - turning right',
        'Roundabouts',
        'Pedestrian crossings',
        'Clearance and obstructions',
      ],
    ),
    // Section 5 - Low-speed control
    SkillSection(
      title: 'Manoeuvres',
      icon: 'swap_calls',
      skills: [
        'Parallel parking',
        'Bay parking (forward and reverse)',
        'Pulling up on the right and reversing',
        'Emergency/controlled stop',
        'Hill start',
      ],
    ),
    // Section 6 - Different road types
    SkillSection(
      title: 'Road Types',
      icon: 'road',
      skills: [
        'Country roads',
        'Dual carriageways',
        'Motorway driving',
      ],
    ),
    // Section 7 - Environmental challenges
    SkillSection(
      title: 'Driving Conditions',
      icon: 'wb_cloudy',
      skills: [
        'Driving in the dark',
        'Weather conditions (rain, fog, ice)',
        'Eco-safe driving',
      ],
    ),
    // Section 8 - Test readiness
    SkillSection(
      title: 'Test Readiness',
      icon: 'emoji_events',
      skills: [
        'Independent driving and sat nav',
        'Progress - appropriate speed',
        'Progress - undue hesitation',
      ],
    ),
  ];
}

class SkillSection {
  const SkillSection({
    required this.title,
    required this.icon,
    required this.skills,
  });

  final String title;
  final String icon;
  final List<String> skills;
}
