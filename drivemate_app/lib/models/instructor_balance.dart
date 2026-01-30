import 'package:cloud_firestore/cloud_firestore.dart';

class InstructorBalance {
  InstructorBalance({
    required this.id,
    required this.instructorId,
    required this.schoolId,
    required this.periodType,
    required this.periodStart,
    required this.totalPaidToInstructor,
    required this.totalPaidToSchool,
    required this.feeAmount,
    required this.netBalance,
  });

  final String id;
  final String instructorId;
  final String schoolId;
  final String periodType;
  final DateTime periodStart;
  final double totalPaidToInstructor;
  final double totalPaidToSchool;
  final double feeAmount;
  final double netBalance;

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'schoolId': schoolId,
      'periodType': periodType,
      'periodStart': Timestamp.fromDate(periodStart),
      'totalPaidToInstructor': totalPaidToInstructor,
      'totalPaidToSchool': totalPaidToSchool,
      'feeAmount': feeAmount,
      'netBalance': netBalance,
    };
  }

  static InstructorBalance fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InstructorBalance(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      schoolId: (data['schoolId'] ?? '') as String,
      periodType: (data['periodType'] ?? 'week') as String,
      periodStart: _toDateTime(data['periodStart']) ?? DateTime.now(),
      totalPaidToInstructor: _toDouble(data['totalPaidToInstructor']),
      totalPaidToSchool: _toDouble(data['totalPaidToSchool']),
      feeAmount: _toDouble(data['feeAmount']),
      netBalance: _toDouble(data['netBalance']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
