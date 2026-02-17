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

  static const List<String> predefinedSkills = [
    'Parallel Parking',
    'Reverse Bay Parking',
    'Highway Driving',
    'Roundabouts',
    'Emergency Stop',
    'Hill Start',
    'Junctions',
    'Independent Driving',
    'Mirror Checks',
    'Speed Control',
  ];
}
