import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/payment.dart';
import '../../models/school_instructor.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
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
      return const Center(child: Text('School not set up.'));
    }
    return StreamBuilder<List<SchoolInstructor>>(
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
            return ListView.separated(
              itemCount: links.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = links[index];
                final hasAccess =
                    latestRequestByInstructor[link.instructorId]?.status ==
                        'approved';
                return FutureBuilder<UserProfile?>(
                  future:
                      _firestoreService.getUserProfile(link.instructorId),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data;
                    final name = profile?.name ?? 'Instructor';
                    if (!hasAccess) {
                      return ListTile(
                        title: Text(name),
                        subtitle: const Text('Access not approved yet.'),
                      );
                    }
                    return StreamBuilder<List<Payment>>(
                      stream: _firestoreService
                          .streamPaymentsForInstructor(link.instructorId),
                      builder: (context, paymentSnapshot) {
                        if (paymentSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final payments = paymentSnapshot.data ?? [];
                        final now = DateTime.now();
                        final weekStart = _startOfWeek(now);
                        final weekEnd = weekStart.add(const Duration(days: 7));
                        final monthStart = DateTime(now.year, now.month, 1);
                        final monthEnd = DateTime(now.year, now.month + 1, 1);

                        final weekSummary =
                            _summarize(payments, weekStart, weekEnd, link);
                        final monthSummary =
                            _summarize(payments, monthStart, monthEnd, link);

                        return ExpansionTile(
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
                            _BalanceCard(
                              title: 'This month',
                              subtitle: DateFormat('MMMM yyyy').format(now),
                              totalPaidToInstructor:
                                  monthSummary.totalPaidToInstructor,
                              totalPaidToSchool: monthSummary.totalPaidToSchool,
                              feeDue: monthSummary.feeDue,
                              netBalance: monthSummary.netBalance,
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

  _BalanceSummary _summarize(
    List<Payment> payments,
    DateTime start,
    DateTime end,
    SchoolInstructor link,
  ) {
    final inRange = payments.where(
      (payment) =>
          !payment.createdAt.isBefore(start) && payment.createdAt.isBefore(end),
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

  DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(start.year, start.month, start.day);
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
