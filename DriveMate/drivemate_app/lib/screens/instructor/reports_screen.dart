import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../widgets/loading_view.dart';

class ReportsScreen extends StatelessWidget {
  ReportsScreen({super.key, required this.instructor});

  final UserProfile instructor;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Payment>>(
      stream: _firestoreService.streamPaymentsForInstructor(instructor.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading reports...');
        }
        final payments = snapshot.data ?? [];
        final now = DateTime.now();
        final weekStart = _startOfWeek(now);
        final weekEnd = weekStart.add(const Duration(days: 7));
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year + 1, 1, 1);

        final weekTotal = _sumInRange(payments, weekStart, weekEnd);
        final monthTotal = _sumInRange(payments, monthStart, monthEnd);
        final yearTotal = _sumInRange(payments, yearStart, yearEnd);

        return StreamBuilder(
          stream:
              _firestoreService.streamInstructorSchoolLink(instructor.id),
          builder: (context, linkSnapshot) {
            final link = linkSnapshot.data;
            final weekPaidToSchool =
                _sumPaidToSchool(payments, weekStart, weekEnd);
            final monthPaidToSchool =
                _sumPaidToSchool(payments, monthStart, monthEnd);
            final weekFee = link != null && link.feeFrequency == 'week'
                ? link.feeAmount
                : 0.0;
            final monthFee = link != null && link.feeFrequency == 'month'
                ? link.feeAmount
                : 0.0;
            final weekNet = weekPaidToSchool - weekFee;
            final monthNet = monthPaidToSchool - monthFee;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReportCard(
                  title: 'This week',
                  value: weekTotal,
                  subtitle:
                      '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
                ),
                _BalanceCard(
                  title: 'Weekly balance',
                  paidToSchool: weekPaidToSchool,
                  feeDue: weekFee,
                  netBalance: weekNet,
                ),
                _ReportCard(
                  title: 'This month',
                  value: monthTotal,
                  subtitle: DateFormat('MMMM yyyy').format(now),
                ),
                _BalanceCard(
                  title: 'Monthly balance',
                  paidToSchool: monthPaidToSchool,
                  feeDue: monthFee,
                  netBalance: monthNet,
                ),
                _ReportCard(
                  title: 'This year',
                  value: yearTotal,
                  subtitle: DateFormat('yyyy').format(now),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _sumInRange(List<Payment> payments, DateTime start, DateTime end) {
    return payments
        .where(
          (payment) =>
              !payment.createdAt.isBefore(start) &&
              payment.createdAt.isBefore(end),
        )
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  double _sumPaidToSchool(
    List<Payment> payments,
    DateTime start,
    DateTime end,
  ) {
    return payments
        .where(
          (payment) =>
              payment.paidTo == 'school' &&
              !payment.createdAt.isBefore(start) &&
              payment.createdAt.isBefore(end),
        )
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final double value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '£${value.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.paidToSchool,
    required this.feeDue,
    required this.netBalance,
  });

  final String title;
  final double paidToSchool;
  final double feeDue;
  final double netBalance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Paid to school: £${paidToSchool.toStringAsFixed(2)}'),
            Text('Fee due: £${feeDue.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Net balance (school → instructor): £${netBalance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
