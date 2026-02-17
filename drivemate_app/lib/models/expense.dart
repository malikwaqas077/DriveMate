import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Expense {
  Expense({
    required this.id,
    required this.schoolId,
    required this.instructorId,
    required this.category,
    required this.description,
    required this.amount,
    this.currency = 'GBP',
    required this.date,
    required this.paymentMethod,
    this.receiptLocalPath,
    this.notes,
    this.csvImportSource,
    required this.createdAt,
  });

  final String id;
  final String schoolId;
  final String instructorId;
  final String category;
  final String description;
  final double amount;
  final String currency;
  final DateTime date;
  final String paymentMethod;
  final String? receiptLocalPath;
  final String? notes;
  final String? csvImportSource;
  final DateTime createdAt;

  static const List<String> categories = [
    'fuel',
    'vehicle_maintenance',
    'insurance',
    'office',
    'marketing',
    'training',
    'equipment',
    'other',
  ];

  static String categoryLabel(String category) {
    switch (category) {
      case 'fuel':
        return 'Fuel';
      case 'vehicle_maintenance':
        return 'Vehicle Maintenance';
      case 'insurance':
        return 'Insurance';
      case 'office':
        return 'Office';
      case 'marketing':
        return 'Marketing';
      case 'training':
        return 'Training';
      case 'equipment':
        return 'Equipment';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  static IconData categoryIcon(String category) {
    switch (category) {
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'vehicle_maintenance':
        return Icons.build_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'office':
        return Icons.business_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'training':
        return Icons.school_rounded;
      case 'equipment':
        return Icons.handyman_rounded;
      case 'other':
        return Icons.receipt_long_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Expense copyWith({
    String? id,
    String? schoolId,
    String? instructorId,
    String? category,
    String? description,
    double? amount,
    String? currency,
    DateTime? date,
    String? paymentMethod,
    String? receiptLocalPath,
    String? notes,
    String? csvImportSource,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      instructorId: instructorId ?? this.instructorId,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      notes: notes ?? this.notes,
      csvImportSource: csvImportSource ?? this.csvImportSource,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'instructorId': instructorId,
      'category': category,
      'description': description,
      'amount': amount,
      'currency': currency,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      if (receiptLocalPath != null) 'receiptLocalPath': receiptLocalPath,
      if (notes != null) 'notes': notes,
      if (csvImportSource != null) 'csvImportSource': csvImportSource,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Expense fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Expense(
      id: doc.id,
      schoolId: (data['schoolId'] ?? '') as String,
      instructorId: (data['instructorId'] ?? '') as String,
      category: (data['category'] ?? 'other') as String,
      description: (data['description'] ?? '') as String,
      amount: _toDouble(data['amount']),
      currency: (data['currency'] ?? 'GBP') as String,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: (data['paymentMethod'] ?? 'cash') as String,
      receiptLocalPath: data['receiptLocalPath'] as String?,
      notes: data['notes'] as String?,
      csvImportSource: data['csvImportSource'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
