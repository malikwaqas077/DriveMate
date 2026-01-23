import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class StudentDetailScreen extends StatelessWidget {
  StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;
  final FirestoreService _firestoreService = FirestoreService();

  final _currencyFormat = NumberFormat.currency(symbol: '£');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(studentName)),
      body: StreamBuilder<Student?>(
        stream: _firestoreService.streamStudentById(studentId),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading student...');
          }
          final student = studentSnapshot.data;
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStudentCard(context, student),
              const SizedBox(height: 16),
              _buildLoginSection(),
              const SizedBox(height: 16),
              _buildPaymentsSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Student student) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(student.name, style: theme.textTheme.titleLarge),
            if ((student.email ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(student.email ?? ''),
            ],
            if ((student.phone ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(student.phone ?? ''),
            ],
            if ((student.licenseNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Licence: ${student.licenseNumber}'),
            ],
            const SizedBox(height: 12),
            Text(
              'Balance: ${student.balanceHours.toStringAsFixed(1)} hours',
            ),
            const SizedBox(height: 4),
            Text(_formatHourlyRate(student.hourlyRate)),
            const SizedBox(height: 4),
            Text('Status: ${student.status}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginSection() {
    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.streamUserProfileByStudentId(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading login...');
        }
        final profile = snapshot.data;
        return _buildLoginCard(context, profile);
      },
    );
  }

  Widget _buildLoginCard(BuildContext context, UserProfile? profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (profile == null) ...[
              const Text('No login created yet.'),
              const SizedBox(height: 4),
              const Text('Create a login to allow student access.'),
            ] else ...[
              Text('Login email: ${profile.email}'),
              const SizedBox(height: 4),
              Text('User ID: ${profile.id}'),
              const SizedBox(height: 4),
              const Text('Password: reset via email if needed.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return StreamBuilder<List<Payment>>(
      stream: _firestoreService.streamPaymentsForStudent(studentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[payments] error: ${snapshot.error}');
        }
        debugPrint(
          '[payments] state=${snapshot.connectionState} '
          'count=${snapshot.data?.length ?? 0}',
        );
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading payments...');
        }
        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return const EmptyView(message: 'No payments yet.');
        }
        return Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                title: Text('${payment.method} · ${payment.hoursPurchased}h'),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(payment.createdAt),
                ),
                trailing: Text(
                  _currencyFormat.format(payment.amount),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatHourlyRate(double? hourlyRate) {
    if (hourlyRate == null) return 'Rate: not set';
    return 'Rate: £${hourlyRate.toStringAsFixed(2)}/h';
  }
}
