import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/school_instructor.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class OwnerReportsScreen extends StatelessWidget {
  OwnerReportsScreen({super.key, required this.owner});

  final UserProfile owner;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final schoolId = owner.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('School Reports')),
        body: const Center(child: Text('School not set up.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('School Reports')),
      body: StreamBuilder<List<SchoolInstructor>>(
        stream: _firestoreService.streamSchoolInstructors(schoolId),
        builder: (context, linkSnapshot) {
          if (linkSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading reports...');
          }
          final links = linkSnapshot.data ?? [];
          if (links.isEmpty) {
            return const EmptyView(message: 'No instructors yet.');
          }
          return StreamBuilder<List<AccessRequest>>(
            stream: _firestoreService.streamAccessRequestsForSchool(schoolId),
            builder: (context, accessSnapshot) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading access...');
              }
              final requests = accessSnapshot.data ?? [];
              final latestRequestByInstructor = <String, AccessRequest>{};
              for (final request in requests) {
                final existing = latestRequestByInstructor[request.instructorId];
                if (existing == null ||
                    (request.createdAt ?? DateTime(0))
                        .isAfter(existing.createdAt ?? DateTime(0))) {
                  latestRequestByInstructor[request.instructorId] = request;
                }
              }
              final approvedLinks =
                  links.where((l) => latestRequestByInstructor[l.instructorId]?.status == 'approved').toList();
              return StreamBuilder<List<Payment>>(
                stream: _firestoreService.streamPaymentsForSchool(schoolId),
                builder: (context, schoolPaymentsSnapshot) {
                  if (schoolPaymentsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LoadingView(message: 'Loading school totals...');
                  }
                  final schoolPayments = schoolPaymentsSnapshot.data ?? [];
                  final now = DateTime.now();
                  final weekStart = _startOfWeek(now);
                  final weekEnd = weekStart.add(const Duration(days: 7));
                  final monthStart = DateTime(now.year, now.month, 1);
                  final monthEnd = DateTime(now.year, now.month + 1, 1);

                  final weekToSchool = _sumPaidTo(schoolPayments, weekStart, weekEnd, 'school');
                  final weekToInstructor = _sumPaidTo(schoolPayments, weekStart, weekEnd, 'instructor');
                  final monthToSchool = _sumPaidTo(schoolPayments, monthStart, monthEnd, 'school');
                  final monthToInstructor = _sumPaidTo(schoolPayments, monthStart, monthEnd, 'instructor');

                  double weekFeeDue = 0;
                  double monthFeeDue = 0;
                  for (final link in approvedLinks) {
                    if (link.feeFrequency == 'week') weekFeeDue += link.feeAmount;
                    if (link.feeFrequency == 'month') monthFeeDue += link.feeAmount;
                  }
                  final weekNet = weekToSchool - weekFeeDue;
                  final monthNet = monthToSchool - monthFeeDue;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionTitle(context, 'School summary'),
                      _SchoolSummaryCard(
                        weekToSchool: weekToSchool,
                        weekToInstructor: weekToInstructor,
                        weekFeeDue: weekFeeDue,
                        weekNet: weekNet,
                        monthToSchool: monthToSchool,
                        monthToInstructor: monthToInstructor,
                        monthFeeDue: monthFeeDue,
                        monthNet: monthNet,
                        weekStart: weekStart,
                        weekEnd: weekEnd,
                        now: now,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'By instructor'),
                      ...links.map((link) {
                        final hasAccess =
                            latestRequestByInstructor[link.instructorId]?.status == 'approved';
                        return _InstructorReportTile(
                          link: link,
                          hasAccess: hasAccess,
                          firestoreService: _firestoreService,
                          weekStart: weekStart,
                          weekEnd: weekEnd,
                          monthStart: monthStart,
                          monthEnd: monthEnd,
                          now: now,
                        );
                      }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  double _sumPaidTo(
      List<Payment> payments, DateTime start, DateTime end, String paidTo) {
    return payments
        .where(
          (p) =>
              p.paidTo == paidTo &&
              !p.createdAt.isBefore(start) &&
              p.createdAt.isBefore(end),
        )
        .fold(0.0, (sum, p) => sum + p.amount);
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

  DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }
}

class _SchoolSummaryCard extends StatelessWidget {
  const _SchoolSummaryCard({
    required this.weekToSchool,
    required this.weekToInstructor,
    required this.weekFeeDue,
    required this.weekNet,
    required this.monthToSchool,
    required this.monthToInstructor,
    required this.monthFeeDue,
    required this.monthNet,
    required this.weekStart,
    required this.weekEnd,
    required this.now,
  });

  final double weekToSchool;
  final double weekToInstructor;
  final double weekFeeDue;
  final double weekNet;
  final double monthToSchool;
  final double monthToInstructor;
  final double monthFeeDue;
  final double monthNet;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('Collected (to school): £${weekToSchool.toStringAsFixed(2)}'),
            Text('Paid to instructors: £${weekToInstructor.toStringAsFixed(2)}'),
            Text('Fees due to instructors: £${weekFeeDue.toStringAsFixed(2)}'),
            Text(
              'Net (school keeps): £${weekNet.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(height: 24),
            Text(
              'This month',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              DateFormat('MMMM yyyy').format(now),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('Collected (to school): £${monthToSchool.toStringAsFixed(2)}'),
            Text('Paid to instructors: £${monthToInstructor.toStringAsFixed(2)}'),
            Text('Fees due to instructors: £${monthFeeDue.toStringAsFixed(2)}'),
            Text(
              'Net (school keeps): £${monthNet.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructorReportTile extends StatelessWidget {
  const _InstructorReportTile({
    required this.link,
    required this.hasAccess,
    required this.firestoreService,
    required this.weekStart,
    required this.weekEnd,
    required this.monthStart,
    required this.monthEnd,
    required this.now,
  });

  final SchoolInstructor link;
  final bool hasAccess;
  final FirestoreService firestoreService;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime monthStart;
  final DateTime monthEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: firestoreService.getUserProfile(link.instructorId),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.name ?? 'Instructor';
        if (!hasAccess) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(name),
              subtitle: const Text('Access not approved yet.'),
            ),
          );
        }
        return StreamBuilder<List<Payment>>(
          stream: firestoreService.streamPaymentsForInstructor(link.instructorId),
          builder: (context, paymentSnapshot) {
            if (paymentSnapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                margin: EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              );
            }
            final payments = paymentSnapshot.data ?? [];
            final weekSummary = _summarize(payments, weekStart, weekEnd, link);
            final monthSummary = _summarize(payments, monthStart, monthEnd, link);
            return StreamBuilder<List<Lesson>>(
              stream: firestoreService.streamLessonsForInstructor(link.instructorId),
              builder: (context, lessonsSnapshot) {
                final lessons = lessonsSnapshot.data ?? [];
                final weekLessons = lessons
                    .where(
                      (l) =>
                          !l.startAt.isBefore(weekStart) &&
                          l.startAt.isBefore(weekEnd),
                    )
                    .toList();
                final monthLessons = lessons
                    .where(
                      (l) =>
                          !l.startAt.isBefore(monthStart) &&
                          l.startAt.isBefore(monthEnd),
                    )
                    .toList();
                final weekCompleted =
                    weekLessons.where((l) => l.status == 'completed').length;
                final monthCompleted =
                    monthLessons.where((l) => l.status == 'completed').length;
                final weekHours =
                    weekLessons.fold(0.0, (s, l) => s + l.durationHours);
                final monthHours =
                    monthLessons.fold(0.0, (s, l) => s + l.durationHours);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(name),
                    subtitle: Text(
                      'Fee: £${link.feeAmount.toStringAsFixed(2)} / ${link.feeFrequency}',
                    ),
                    children: [
                      _BalanceCard(
                        title: 'This week',
                        subtitle:
                            '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
                        totalPaidToInstructor:
                            weekSummary.totalPaidToInstructor,
                        totalPaidToSchool: weekSummary.totalPaidToSchool,
                        feeDue: weekSummary.feeDue,
                        netBalance: weekSummary.netBalance,
                      ),
                      _ActivityCard(
                        title: 'Lessons this week',
                        completed: weekCompleted,
                        totalHours: weekHours,
                      ),
                      _BalanceCard(
                        title: 'This month',
                        subtitle: DateFormat('MMMM yyyy').format(now),
                        totalPaidToInstructor:
                            monthSummary.totalPaidToInstructor,
                        totalPaidToSchool: monthSummary.totalPaidToSchool,
                        feeDue: monthSummary.feeDue,
                        netBalance: monthSummary.netBalance,
                      ),
                      _ActivityCard(
                        title: 'Lessons this month',
                        completed: monthCompleted,
                        totalHours: monthHours,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  _BalanceSummary _summarize(
    List<Payment> payments,
    DateTime start,
    DateTime end,
    SchoolInstructor link,
  ) {
    final inRange = payments.where(
      (payment) =>
          !payment.createdAt.isBefore(start) &&
          payment.createdAt.isBefore(end),
    );
    double toInstructor = 0;
    double toSchool = 0;
    for (final payment in inRange) {
      if (payment.paidTo == 'school') {
        toSchool += payment.amount;
      } else {
        toInstructor += payment.amount;
      }
    }
    final feeDue = link.feeFrequency == _periodForRange(start, end)
        ? link.feeAmount
        : 0.0;
    final netBalance = toSchool - feeDue;
    return _BalanceSummary(
      totalPaidToInstructor: toInstructor,
      totalPaidToSchool: toSchool,
      feeDue: feeDue,
      netBalance: netBalance,
    );
  }

  String _periodForRange(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days >= 28 ? 'month' : 'week';
  }
}

class _BalanceSummary {
  _BalanceSummary({
    required this.totalPaidToInstructor,
    required this.totalPaidToSchool,
    required this.feeDue,
    required this.netBalance,
  });

  final double totalPaidToInstructor;
  final double totalPaidToSchool;
  final double feeDue;
  final double netBalance;
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.subtitle,
    required this.totalPaidToInstructor,
    required this.totalPaidToSchool,
    required this.feeDue,
    required this.netBalance,
  });

  final String title;
  final String subtitle;
  final double totalPaidToInstructor;
  final double totalPaidToSchool;
  final double feeDue;
  final double netBalance;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            Text(
              'Paid to instructor: £${totalPaidToInstructor.toStringAsFixed(2)}',
            ),
            Text('Paid to school: £${totalPaidToSchool.toStringAsFixed(2)}'),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.completed,
    required this.totalHours,
  });

  final String title;
  final int completed;
  final double totalHours;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Completed lessons: $completed'),
            Text('Hours taught: ${totalHours.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }
}
