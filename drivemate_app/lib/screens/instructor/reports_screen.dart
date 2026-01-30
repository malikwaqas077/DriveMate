import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cancellation_request.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_view.dart';

class ReportsScreen extends StatelessWidget {
  ReportsScreen({super.key, required this.instructor});

  final UserProfile instructor;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: _firestoreService.streamLessonsForInstructor(instructor.id),
      builder: (context, lessonsSnapshot) {
        if (lessonsSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading reports...');
        }
        final lessons = lessonsSnapshot.data ?? [];
        return StreamBuilder<List<Student>>(
          stream: _firestoreService.streamStudents(instructor.id),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading students...');
            }
            final students = studentsSnapshot.data ?? [];
            return StreamBuilder<List<CancellationRequest>>(
              stream: _firestoreService
                  .streamCancellationRequestsForInstructor(instructor.id),
              builder: (context, cancellationsSnapshot) {
                if (cancellationsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading cancellations...');
                }
                final cancellations = cancellationsSnapshot.data ?? [];
                return StreamBuilder<List<Payment>>(
                  stream: _firestoreService
                      .streamPaymentsForInstructor(instructor.id),
                  builder: (context, paymentSnapshot) {
                    if (paymentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView(message: 'Loading payments...');
                    }
                    final payments = paymentSnapshot.data ?? [];
                    return StreamBuilder(
                      stream: _firestoreService
                          .streamInstructorSchoolLink(instructor.id),
                      builder: (context, linkSnapshot) {
                        final link = linkSnapshot.data;
                        final now = DateTime.now();
                        final weekStart = _startOfWeek(now);
                        final weekEnd = weekStart.add(const Duration(days: 7));
                        final monthStart = DateTime(now.year, now.month, 1);
                        final monthEnd =
                            DateTime(now.year, now.month + 1, 1);
                        final yearStart = DateTime(now.year, 1, 1);
                        final yearEnd = DateTime(now.year + 1, 1, 1);

                        // Earnings
                        final weekTotal =
                            _sumInRange(payments, weekStart, weekEnd);
                        final monthTotal =
                            _sumInRange(payments, monthStart, monthEnd);
                        final yearTotal =
                            _sumInRange(payments, yearStart, yearEnd);
                        final weekPaidToSchool =
                            _sumPaidToSchool(payments, weekStart, weekEnd);
                        final monthPaidToSchool =
                            _sumPaidToSchool(payments, monthStart, monthEnd);
                        final weekFee = link != null && link.feeFrequency == 'week'
                            ? link.feeAmount
                            : 0.0;
                        final monthFee =
                            link != null && link.feeFrequency == 'month'
                                ? link.feeAmount
                                : 0.0;
                        final weekNet = weekPaidToSchool - weekFee;
                        final monthNet = monthPaidToSchool - monthFee;

                        // Lessons (filter by date range)
                        final weekLessons = _lessonsInRange(
                            lessons, weekStart, weekEnd);
                        final monthLessons = _lessonsInRange(
                            lessons, monthStart, monthEnd);
                        final yearLessons = _lessonsInRange(
                            lessons, yearStart, yearEnd);

                        // Cancellations in period
                        final monthCancellations = cancellations.where((c) =>
                            !c.createdAt.isBefore(monthStart) &&
                            c.createdAt.isBefore(monthEnd));
                        final pendingCount = cancellations
                            .where((c) => c.status == 'pending')
                            .length;

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _sectionTitle(context, 'Earnings'),
                            _ReportCard(
                              title: 'This week',
                              value: weekTotal,
                              subtitle:
                                  '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
                            ),
                            _ReportCard(
                              title: 'This month',
                              value: monthTotal,
                              subtitle: DateFormat('MMMM yyyy').format(now),
                            ),
                            _ReportCard(
                              title: 'This year',
                              value: yearTotal,
                              subtitle: DateFormat('yyyy').format(now),
                            ),
                            if (link != null) ...[
                              const SizedBox(height: 8),
                              _BalanceCard(
                                title: 'Weekly balance (school)',
                                paidToSchool: weekPaidToSchool,
                                feeDue: weekFee,
                                netBalance: weekNet,
                              ),
                              _BalanceCard(
                                title: 'Monthly balance (school)',
                                paidToSchool: monthPaidToSchool,
                                feeDue: monthFee,
                                netBalance: monthNet,
                              ),
                            ],
                            const SizedBox(height: 24),
                            _sectionTitle(context, 'Lessons'),
                            _LessonsSummaryCard(
                              weekLessons: weekLessons,
                              monthLessons: monthLessons,
                              yearLessons: yearLessons,
                              weekStart: weekStart,
                              weekEnd: weekEnd,
                              now: now,
                            ),
                            const SizedBox(height: 24),
                            _sectionTitle(context, 'Students'),
                            _StudentsSummaryCard(students: students),
                            const SizedBox(height: 24),
                            _sectionTitle(context, 'Cancellations'),
                            _CancellationsSummaryCard(
                              pendingCount: pendingCount,
                              monthCancellations: monthCancellations.toList(),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  double _sumInRange(
      List<Payment> payments, DateTime start, DateTime end) {
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

  List<Lesson> _lessonsInRange(
      List<Lesson> lessons, DateTime start, DateTime end) {
    return lessons
        .where(
          (l) =>
              !l.startAt.isBefore(start) && l.startAt.isBefore(end),
        )
        .toList();
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

class _LessonsSummaryCard extends StatelessWidget {
  const _LessonsSummaryCard({
    required this.weekLessons,
    required this.monthLessons,
    required this.yearLessons,
    required this.weekStart,
    required this.weekEnd,
    required this.now,
  });

  final List<Lesson> weekLessons;
  final List<Lesson> monthLessons;
  final List<Lesson> yearLessons;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final weekCompleted = weekLessons.where((l) => l.status == 'completed').toList();
    final weekScheduled = weekLessons.where((l) => l.status == 'scheduled').toList();
    final weekCancelled = weekLessons.where((l) => l.status == 'cancelled').toList();
    final monthCompleted = monthLessons.where((l) => l.status == 'completed').toList();
    final yearCompleted = yearLessons.where((l) => l.status == 'completed').toList();

    double hours(List<Lesson> list) =>
        list.fold(0, (sum, l) => sum + l.durationHours);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: Theme.of(context).textTheme.titleSmall),
            Text(
              '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(context, 'Completed', weekCompleted.length, AppTheme.success),
                const SizedBox(width: 8),
                _chip(context, 'Scheduled', weekScheduled.length, AppTheme.info),
                const SizedBox(width: 8),
                _chip(context, 'Cancelled', weekCancelled.length, AppTheme.warning),
              ],
            ),
            Text(
              'Hours: ${hours(weekLessons).toStringAsFixed(1)} total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text('This month', style: Theme.of(context).textTheme.titleSmall),
            Text(
              DateFormat('MMMM yyyy').format(now),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Completed: ${monthCompleted.length} lessons, ${hours(monthCompleted).toStringAsFixed(1)} hours',
            ),
            const Divider(height: 24),
            Text('This year', style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Completed: ${yearCompleted.length} lessons, ${hours(yearCompleted).toStringAsFixed(1)} hours',
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int count, Color color) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StudentsSummaryCard extends StatelessWidget {
  const _StudentsSummaryCard({required this.students});

  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    final byStatus = <String, int>{};
    for (final s in students) {
      byStatus[s.status] = (byStatus[s.status] ?? 0) + 1;
    }
    final statusList = byStatus.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total students: ${students.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (statusList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statusList
                    .map((e) => Chip(
                          label: Text('${e.key}: ${e.value}'),
                          backgroundColor: AppTheme.infoLight.withValues(alpha: 0.5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CancellationsSummaryCard extends StatelessWidget {
  const _CancellationsSummaryCard({
    required this.pendingCount,
    required this.monthCancellations,
  });

  final int pendingCount;
  final List<CancellationRequest> monthCancellations;

  @override
  Widget build(BuildContext context) {
    final approved = monthCancellations.where((c) => c.status == 'approved').length;
    final declined = monthCancellations.where((c) => c.status == 'declined').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$pendingCount pending request(s)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.warning,
                          ),
                    ),
                  ],
                ),
              ),
            Text('This month', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Approved: $approved'),
            Text('Declined: $declined'),
          ],
        ),
      ),
    );
  }
}
