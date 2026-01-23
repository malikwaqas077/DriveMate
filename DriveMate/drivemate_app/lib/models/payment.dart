import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  Payment({
    required this.id,
    required this.instructorId,
    required this.studentId,
    this.schoolId,
    required this.amount,
    required this.currency,
    required this.method,
    this.paidTo = 'instructor',
    required this.hoursPurchased,
    required this.createdAt,
  });

  final String id;
  final String instructorId;
  final String studentId;
  final String? schoolId;
  final double amount;
  final String currency;
  final String method;
  final String paidTo;
  final double hoursPurchased;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'instructorId': instructorId,
      'studentId': studentId,
      'schoolId': schoolId,
      'amount': amount,
      'currency': currency,
      'method': method,
      'paidTo': paidTo,
      'hoursPurchased': hoursPurchased,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Payment fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Payment(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      schoolId: data['schoolId'] as String?,
      amount: _toDouble(data['amount']),
      currency: (data['currency'] ?? 'GBP') as String,
      method: (data['method'] ?? 'cash') as String,
      paidTo: (data['paidTo'] ?? 'instructor') as String,
      hoursPurchased: _toDouble(data['hoursPurchased']),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }
}
