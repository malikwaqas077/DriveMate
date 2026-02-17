import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/expense.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/school_instructor.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key, required this.owner});

  final UserProfile owner;

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.owner.schoolId;
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
              return const LoadingView(message: 'Loading...');
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
            final approvedLinks = links
                .where((l) =>
                    latestRequestByInstructor[l.instructorId]?.status ==
                    'approved')
                .toList();

            return StreamBuilder<List<Payment>>(
              stream: _firestoreService.streamPaymentsForSchool(schoolId),
              builder: (context, paymentsSnapshot) {
                if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading payments...');
                }
                final payments = paymentsSnapshot.data ?? [];

                return StreamBuilder<List<Expense>>(
                  stream: _firestoreService.streamExpensesForSchool(schoolId),
                  builder: (context, expensesSnapshot) {
                    final expenses = expensesSnapshot.data ?? [];

                    return _buildContent(
                      context,
                      links,
                      approvedLinks,
                      latestRequestByInstructor,
                      payments,
                      expenses,
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

  Widget _buildContent(
    BuildContext context,
    List<SchoolInstructor> allLinks,
    List<SchoolInstructor> approvedLinks,
    Map<String, AccessRequest> latestRequestByInstructor,
    List<Payment> payments,
    List<Expense> expenses,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
    final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 1);
    final prevMonthStart = DateTime(_selectedYear, _selectedMonth - 1, 1);
    final prevMonthEnd = monthStart;
    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear + 1, 1, 1);

    // Current month metrics
    final monthToSchool = _sumPaidTo(payments, monthStart, monthEnd, 'school');
    final monthToInstructor =
        _sumPaidTo(payments, monthStart, monthEnd, 'instructor');
    final monthTotal = monthToSchool + monthToInstructor;

    // Previous month metrics
    final prevMonthToSchool =
        _sumPaidTo(payments, prevMonthStart, prevMonthEnd, 'school');
    final prevMonthTotal = prevMonthToSchool +
        _sumPaidTo(payments, prevMonthStart, prevMonthEnd, 'instructor');

    // Year metrics
    final yearToSchool = _sumPaidTo(payments, yearStart, yearEnd, 'school');
    final yearTotal = yearToSchool +
        _sumPaidTo(payments, yearStart, yearEnd, 'instructor');

    // Expense metrics
    final monthExpenses = _sumExpensesInRange(expenses, monthStart, monthEnd);
    final yearExpenses = _sumExpensesInRange(expenses, yearStart, yearEnd);

    // Calculate fees
    double monthFeeDue = 0;
    for (final link in approvedLinks) {
      if (link.feeFrequency == 'month') monthFeeDue += link.feeAmount;
    }
    final monthNet = monthToSchool - monthFeeDue - monthExpenses;

    // Month change
    final monthChange = prevMonthTotal > 0
        ? ((monthTotal - prevMonthTotal) / prevMonthTotal * 100)
        : (monthTotal > 0 ? 100.0 : 0.0);

    // Earnings trend
    final earningsTrend = _calculateEarningsTrend(payments, now);

    // Expense category breakdown for selected month
    final categoryBreakdown = _expenseCategoryBreakdown(expenses, monthStart, monthEnd);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Month selector
        _buildMonthSelector(context),
        const SizedBox(height: 16),

        // Revenue overview card
        _buildRevenueOverviewCard(
          context,
          monthTotal,
          monthChange,
          yearTotal,
          earningsTrend,
          monthExpenses: monthExpenses,
          yearExpenses: yearExpenses,
        ),
        const SizedBox(height: 16),

        // Quick stats
        _buildQuickStats(
          context,
          monthToSchool,
          monthToInstructor,
          monthNet,
          monthFeeDue,
          monthExpenses: monthExpenses,
        ),
        const SizedBox(height: 24),

        // Expense Breakdown
        if (categoryBreakdown.isNotEmpty) ...[
          _buildSectionHeader(context, 'Expense Breakdown', Icons.receipt_long_rounded),
          const SizedBox(height: 12),
          _buildExpenseBreakdown(context, categoryBreakdown),
          const SizedBox(height: 24),
        ],

        // Feature 2.8: Enhanced analytics - Retention & Completion
        _buildSectionHeader(context, 'Key Metrics', Icons.analytics_rounded),
        const SizedBox(height: 12),
        _buildKeyMetricsCards(context, allLinks, payments, monthStart, monthEnd),
        const SizedBox(height: 24),

        // Instructor performance section
        _buildSectionHeader(context, 'Instructor Performance', Icons.people_rounded),
        const SizedBox(height: 12),
        ...allLinks.map((link) {
          final hasAccess = latestRequestByInstructor[link.instructorId]?.status ==
              'approved';
          return _InstructorPerformanceCard(
            link: link,
            hasAccess: hasAccess,
            firestoreService: _firestoreService,
            monthStart: monthStart,
            monthEnd: monthEnd,
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
          );
        }),
      ],
    );
  }

  double _sumExpensesInRange(List<Expense> expenses, DateTime start, DateTime end) {
    return expenses
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> _expenseCategoryBreakdown(
    List<Expense> expenses, DateTime start, DateTime end,
  ) {
    final map = <String, double>{};
    for (final e in expenses) {
      if (!e.date.isBefore(start) && e.date.isBefore(end)) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }

  Widget _buildExpenseBreakdown(
    BuildContext context,
    Map<String, double> categoryBreakdown,
  ) {
    final sorted = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < sorted.length ? 12 : 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    icon: Expense.categoryIcon(sorted[i].key),
                    label: Expense.categoryLabel(sorted[i].key),
                    value: '£${sorted[i].value.toStringAsFixed(0)}',
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < sorted.length
                      ? _buildMetricCard(
                          context,
                          icon: Expense.categoryIcon(sorted[i + 1].key),
                          label: Expense.categoryLabel(sorted[i + 1].key),
                          value: '£${sorted[i + 1].value.toStringAsFixed(0)}',
                          color: AppTheme.error,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKeyMetricsCards(
    BuildContext context,
    List<SchoolInstructor> allLinks,
    List<Payment> payments,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Revenue per instructor for this month
    final revenuePerInstructor = <String, double>{};
    for (final link in allLinks) {
      final instructorRevenue = payments
          .where((p) =>
              p.instructorId == link.instructorId &&
              p.paidTo == 'school' &&
              !p.createdAt.isBefore(monthStart) &&
              p.createdAt.isBefore(monthEnd))
          .fold<double>(0, (sum, p) => sum + p.amount);
      revenuePerInstructor[link.instructorId] = instructorRevenue;
    }

    final totalMonthPayments = payments
        .where((p) =>
            !p.createdAt.isBefore(monthStart) && p.createdAt.isBefore(monthEnd))
        .length;
    final totalPayments = payments.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.people_outline_rounded,
                label: 'Active Instructors',
                value: '${allLinks.length}',
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.receipt_long_rounded,
                label: 'Payments This Month',
                value: '$totalMonthPayments',
                color: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.trending_up_rounded,
                label: 'Avg Revenue/Instructor',
                value: allLinks.isNotEmpty
                    ? '£${(revenuePerInstructor.values.fold(0.0, (a, b) => a + b) / allLinks.length).toStringAsFixed(0)}'
                    : '£0',
                color: AppTheme.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.payment_rounded,
                label: 'Total Payments',
                value: '$totalPayments',
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy')
                  .format(DateTime(_selectedYear, _selectedMonth)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              final now = DateTime.now();
              if (_selectedYear < now.year ||
                  (_selectedYear == now.year && _selectedMonth < now.month)) {
                setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                  } else {
                    _selectedMonth++;
                  }
                });
              }
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverviewCard(
    BuildContext context,
    double monthTotal,
    double monthChange,
    double yearTotal,
    List<_TrendPoint> trend, {
    double monthExpenses = 0,
    double yearExpenses = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = monthChange >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '£${monthTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${monthChange.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (monthExpenses > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Expenses: £${monthExpenses.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
          Text(
            'Year to date: £${yearTotal.toStringAsFixed(2)}${yearExpenses > 0 ? ' (expenses: £${yearExpenses.toStringAsFixed(2)})' : ''}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: _MiniChart(trend: trend),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    double toSchool,
    double toInstructor,
    double net,
    double feeDue, {
    double monthExpenses = 0,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                label: 'To School',
                value: '£${toSchool.toStringAsFixed(0)}',
                icon: Icons.business_rounded,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickStatCard(
                label: 'To Instructors',
                value: '£${toInstructor.toStringAsFixed(0)}',
                icon: Icons.person_rounded,
                color: AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                label: 'Expenses',
                value: '£${monthExpenses.toStringAsFixed(0)}',
                icon: Icons.receipt_long_rounded,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickStatCard(
                label: 'Net Profit',
                value: '£${net.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded,
                color: net >= 0 ? AppTheme.primary : AppTheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  double _sumPaidTo(
    List<Payment> payments,
    DateTime start,
    DateTime end,
    String paidTo,
  ) {
    return payments
        .where((p) =>
            p.paidTo == paidTo &&
            !p.createdAt.isBefore(start) &&
            p.createdAt.isBefore(end))
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  List<_TrendPoint> _calculateEarningsTrend(List<Payment> payments, DateTime now) {
    final points = <_TrendPoint>[];

    for (var i = 5; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = DateTime(now.year, now.month - i + 1, 1);
      final amount = payments
          .where(
              (p) => !p.createdAt.isBefore(start) && p.createdAt.isBefore(end))
          .fold<double>(0, (sum, p) => sum + p.amount);
      points.add(_TrendPoint(label: DateFormat('MMM').format(start), value: amount));
    }

    return points;
  }
}

class _TrendPoint {
  _TrendPoint({required this.label, required this.value});
  final String label;
  final double value;
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.trend});

  final List<_TrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxValue = trend.map((t) => t.value).reduce(math.max);
    if (maxValue == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final barWidth = (width - (trend.length - 1) * 8) / trend.length;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: trend.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final barHeight = (point.value / maxValue) * height * 0.8;

            return Padding(
              padding: EdgeInsets.only(right: index < trend.length - 1 ? 8 : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: barWidth,
                    height: math.max(barHeight, 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructorPerformanceCard extends StatelessWidget {
  const _InstructorPerformanceCard({
    required this.link,
    required this.hasAccess,
    required this.firestoreService,
    required this.monthStart,
    required this.monthEnd,
    required this.selectedMonth,
    required this.selectedYear,
  });

  final SchoolInstructor link;
  final bool hasAccess;
  final FirestoreService firestoreService;
  final DateTime monthStart;
  final DateTime monthEnd;
  final int selectedMonth;
  final int selectedYear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<UserProfile?>(
      future: firestoreService.getUserProfile(link.instructorId),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.name ?? 'Instructor';

        if (!hasAccess) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.neutral200,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutral500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Access pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<List<Payment>>(
          stream: firestoreService.streamPaymentsForInstructor(link.instructorId),
          builder: (context, paymentSnapshot) {
            final payments = paymentSnapshot.data ?? [];
            final monthPayments = payments
                .where((p) =>
                    !p.createdAt.isBefore(monthStart) &&
                    p.createdAt.isBefore(monthEnd))
                .toList();

            final toSchool = monthPayments
                .where((p) => p.paidTo == 'school')
                .fold<double>(0, (sum, p) => sum + p.amount);
            final toInstructor = monthPayments
                .where((p) => p.paidTo == 'instructor')
                .fold<double>(0, (sum, p) => sum + p.amount);
            final total = toSchool + toInstructor;

            return StreamBuilder<List<Lesson>>(
              stream: firestoreService.streamLessonsForInstructor(link.instructorId),
              builder: (context, lessonsSnapshot) {
                final lessons = lessonsSnapshot.data ?? [];
                final monthLessons = lessons
                    .where((l) =>
                        !l.startAt.isBefore(monthStart) &&
                        l.startAt.isBefore(monthEnd))
                    .toList();
                final completedCount =
                    monthLessons.where((l) => l.status == 'completed').length;
                final totalHours =
                    monthLessons.fold<double>(0, (sum, l) => sum + l.durationHours);

                return StreamBuilder<List<Student>>(
                  stream: firestoreService.streamStudents(link.instructorId),
                  builder: (context, studentsSnapshot) {
                    final students = studentsSnapshot.data ?? [];
                    final activeStudents =
                        students.where((s) => s.status == 'active').length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        shape: const Border(),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '£${total.toStringAsFixed(0)} · $completedCount lessons · $activeStudents students',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          // Revenue breakdown
                          _buildDetailRow(
                            context,
                            'Revenue to School',
                            '£${toSchool.toStringAsFixed(2)}',
                            AppTheme.success,
                          ),
                          _buildDetailRow(
                            context,
                            'Revenue to Instructor',
                            '£${toInstructor.toStringAsFixed(2)}',
                            AppTheme.info,
                          ),
                          _buildDetailRow(
                            context,
                            'Fee (${link.feeFrequency})',
                            '£${link.feeAmount.toStringAsFixed(2)}',
                            AppTheme.neutral500,
                          ),
                          const Divider(height: 24),
                          // Activity
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStatBox(
                                  label: 'Lessons',
                                  value: '$completedCount',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniStatBox(
                                  label: 'Hours',
                                  value: totalHours.toStringAsFixed(1),
                                  icon: Icons.schedule_rounded,
                                  color: AppTheme.info,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniStatBox(
                                  label: 'Students',
                                  value: '$activeStudents',
                                  icon: Icons.people_outline_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
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
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
