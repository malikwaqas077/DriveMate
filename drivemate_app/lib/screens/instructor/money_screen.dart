import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  String _expectedIncomePeriod = 'week'; // week, month, all

  static const double _defaultHourlyRate = 40.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _firestoreService.streamStudents(widget.instructor.id),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading...');
        }
        final students = studentsSnapshot.data ?? [];
        final studentMap = {for (final s in students) s.id: s};

        return StreamBuilder<List<Payment>>(
          stream:
              _firestoreService.streamPaymentsForInstructor(widget.instructor.id),
          builder: (context, paymentsSnapshot) {
            if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading payments...');
            }
            final payments = paymentsSnapshot.data ?? [];

            return StreamBuilder<List<Lesson>>(
              stream: _firestoreService
                  .streamLessonsForInstructor(widget.instructor.id),
              builder: (context, lessonsSnapshot) {
                if (lessonsSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading...');
                }
                final lessons = lessonsSnapshot.data ?? [];

                return _buildContent(
                  context,
                  students,
                  studentMap,
                  payments,
                  lessons,
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
    List<Student> students,
    Map<String, Student> studentMap,
    List<Payment> payments,
    List<Lesson> lessons,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Calculate metrics
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = monthStart;
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final yearStart = DateTime(now.year, 1, 1);

    final thisMonth = _sumInRange(payments, monthStart, monthEnd);
    final lastMonth = _sumInRange(payments, lastMonthStart, lastMonthEnd);
    final thisWeek = _sumInRange(payments, weekStart, weekEnd);
    final thisYear = _sumInRange(payments, yearStart, monthEnd);

    final monthChange = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth * 100)
        : (thisMonth > 0 ? 100.0 : 0.0);

    // Expected income from scheduled lessons with period filter
    final expectedIncomeData = _computeExpectedIncomeWithStudents(
      lessons,
      students,
      _expectedIncomePeriod,
    );

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Month earnings hero card
                _buildMonthHeroCard(
                  context,
                  thisMonth,
                  monthChange,
                  lastMonth,
                ),
                // Quick stats row
                _buildQuickStats(context, thisWeek, thisMonth, thisYear),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              colorScheme: colorScheme,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Overview tab
            _buildOverviewTab(
              context,
              expectedIncomeData,
              students,
            ),
            // Transactions tab
            _buildTransactionsTab(
              context,
              payments,
              studentMap,
              students,
            ),
          ],
        ),
      ),
      floatingActionButton: students.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _showAddPayment(context, students, widget.instructor.schoolId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Payment'),
            ),
    );
  }

  Widget _buildMonthHeroCard(
    BuildContext context,
    double thisMonth,
    double monthChange,
    double lastMonth,
  ) {
    final now = DateTime.now();
    final isPositive = monthChange >= 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
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
                    DateFormat('MMMM yyyy').format(now),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '£${thisMonth.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              if (lastMonth > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
          if (lastMonth > 0) ...[
            const SizedBox(height: 12),
            Text(
              'vs £${lastMonth.toStringAsFixed(2)} last month',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    double thisWeek,
    double thisMonth,
    double thisYear,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickStatCard(
              label: 'This Week',
              value: '£${thisWeek.toStringAsFixed(0)}',
              icon: Icons.calendar_view_week_rounded,
              color: AppTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickStatCard(
              label: 'This Month',
              value: '£${thisMonth.toStringAsFixed(0)}',
              icon: Icons.calendar_month_rounded,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickStatCard(
              label: 'This Year',
              value: '£${thisYear.toStringAsFixed(0)}',
              icon: Icons.calendar_today_rounded,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    _ExpectedIncomeData expectedIncomeData,
    List<Student> allStudents,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalExpected = expectedIncomeData.totalAmount;
    final studentBreakdown = expectedIncomeData.byStudent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Expected income section with filter
        _buildExpectedIncomeHeader(context),
        const SizedBox(height: 12),
        
        // Period filter chips
        _buildPeriodFilter(context),
        const SizedBox(height: 16),

        if (studentBreakdown.isEmpty)
          _buildEmptyStateCard(
            context,
            'No scheduled lessons',
            _expectedIncomePeriod == 'week'
                ? 'No lessons scheduled for this week'
                : _expectedIncomePeriod == 'month'
                    ? 'No lessons scheduled for this month'
                    : 'No upcoming lessons scheduled',
            Icons.event_outlined,
            AppTheme.neutral500,
          )
        else ...[
          // Total expected card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.info,
                  AppTheme.info.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.info.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPeriodLabel(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '£${totalExpected.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${studentBreakdown.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'students',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Student breakdown list
          ...studentBreakdown.map((item) => _buildExpectedStudentCard(context, item)),
        ],
      ],
    );
  }

  String _getPeriodLabel() {
    switch (_expectedIncomePeriod) {
      case 'week':
        return 'Expected This Week';
      case 'month':
        return 'Expected This Month';
      default:
        return 'Total Expected';
    }
  }

  Widget _buildExpectedIncomeHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.infoLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.trending_up_rounded, color: AppTheme.info, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected Income',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'From upcoming scheduled lessons',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodFilter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterChip('week', 'This Week'),
          _buildFilterChip('month', 'This Month'),
          _buildFilterChip('all', 'All'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _expectedIncomePeriod == value;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _expectedIncomePeriod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.info : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpectedStudentCard(BuildContext context, _StudentExpectedIncome item) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.info.withOpacity(0.15),
              child: Text(
                item.studentName.isNotEmpty ? item.studentName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.info,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.studentName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.lessonCount} lesson${item.lessonCount == 1 ? '' : 's'} · ${item.totalHours.toStringAsFixed(1)}h @ £${item.hourlyRate.toStringAsFixed(0)}/h',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '£${item.expectedAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ExpectedIncomeData _computeExpectedIncomeWithStudents(
    List<Lesson> lessons,
    List<Student> students,
    String period,
  ) {
    final now = DateTime.now();
    final studentMap = {for (final s in students) s.id: s};
    
    // Determine date range based on period
    late DateTime periodStart, periodEnd;
    switch (period) {
      case 'week':
        periodStart = _startOfWeek(now);
        periodEnd = periodStart.add(const Duration(days: 7));
        break;
      case 'month':
        periodStart = DateTime(now.year, now.month, 1);
        periodEnd = DateTime(now.year, now.month + 1, 1);
        break;
      default: // all
        periodStart = now;
        periodEnd = now.add(const Duration(days: 365)); // next year
    }

    // Filter upcoming scheduled lessons in the period
    final upcoming = lessons.where((l) =>
        l.status == 'scheduled' &&
        l.startAt.isAfter(now) &&
        (period == 'all' || 
         (!l.startAt.isBefore(periodStart) && l.startAt.isBefore(periodEnd)))).toList();

    // Group by student and calculate
    final byStudentMap = <String, _StudentExpectedIncome>{};
    
    for (final lesson in upcoming) {
      final student = studentMap[lesson.studentId];
      final studentName = student?.name ?? 'Unknown Student';
      final rate = student?.hourlyRate ?? _defaultHourlyRate;
      final income = lesson.durationHours * rate;

      if (byStudentMap.containsKey(lesson.studentId)) {
        final existing = byStudentMap[lesson.studentId]!;
        byStudentMap[lesson.studentId] = _StudentExpectedIncome(
          studentId: lesson.studentId,
          studentName: studentName,
          lessonCount: existing.lessonCount + 1,
          totalHours: existing.totalHours + lesson.durationHours,
          hourlyRate: rate,
          expectedAmount: existing.expectedAmount + income,
        );
      } else {
        byStudentMap[lesson.studentId] = _StudentExpectedIncome(
          studentId: lesson.studentId,
          studentName: studentName,
          lessonCount: 1,
          totalHours: lesson.durationHours,
          hourlyRate: rate,
          expectedAmount: income,
        );
      }
    }

    final byStudent = byStudentMap.values.toList()
      ..sort((a, b) => b.expectedAmount.compareTo(a.expectedAmount));

    final total = byStudent.fold<double>(0, (sum, s) => sum + s.expectedAmount);

    return _ExpectedIncomeData(
      totalAmount: total,
      byStudent: byStudent,
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildTransactionsTab(
    BuildContext context,
    List<Payment> payments,
    Map<String, Student> studentMap,
    List<Student> students,
  ) {
    if (payments.isEmpty) {
      return Center(
        child: EmptyView(
          message: 'No payments yet',
          subtitle: 'Record your first payment to get started',
          type: EmptyViewType.payments,
          actionLabel: 'Add Payment',
          onAction: students.isEmpty
              ? null
              : () => _showAddPayment(
                  context, students, widget.instructor.schoolId),
        ),
      );
    }

    // Group by month
    final groupedPayments = <String, List<Payment>>{};
    for (final payment in payments) {
      final monthKey = DateFormat('yyyy-MM').format(payment.createdAt);
      groupedPayments.putIfAbsent(monthKey, () => []).add(payment);
    }

    final sortedMonths = groupedPayments.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = sortedMonths[index];
        final monthPayments = groupedPayments[monthKey]!
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final monthTotal =
            monthPayments.fold<double>(0, (sum, p) => sum + p.amount);
        final date = DateTime.parse('$monthKey-01');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutral500,
                    ),
                  ),
                  Text(
                    '£${monthTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            ...monthPayments.map((payment) => _buildPaymentCard(
                  context,
                  payment,
                  studentMap,
                  students,
                )),
          ],
        );
      },
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    Payment payment,
    Map<String, Student> studentMap,
    List<Student> students,
  ) {
    final student = studentMap[payment.studentId];
    final name = student?.name ?? 'Student';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEditPayment(context, payment),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getMethodBackgroundColor(payment.method),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getMethodIcon(payment.method),
                    color: _getMethodColor(payment.method),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('d MMM, HH:mm').format(payment.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${payment.hoursPurchased.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '+£${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  double _sumInRange(List<Payment> payments, DateTime start, DateTime end) {
    return payments
        .where((p) => !p.createdAt.isBefore(start) && p.createdAt.isBefore(end))
        .fold(0, (sum, p) => sum + p.amount);
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'other':
        return Icons.receipt_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.success;
      case 'bank_transfer':
        return AppTheme.info;
      case 'card':
        return const Color(0xFF8B5CF6);
      case 'other':
        return AppTheme.neutral500;
      default:
        return AppTheme.primary;
    }
  }

  Color _getMethodBackgroundColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.successLight;
      case 'bank_transfer':
        return AppTheme.infoLight;
      case 'card':
        return const Color(0xFFEDE9FE);
      case 'other':
        return AppTheme.neutral100;
      default:
        return AppTheme.primaryLight;
    }
  }

  String _getMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
        return 'Card';
      case 'other':
        return 'Other';
      default:
        final customMethods =
            widget.instructor.instructorSettings?.customPaymentMethods ?? [];
        try {
          final customMethod = customMethods.firstWhere((m) => m.id == method);
          return customMethod.label;
        } catch (_) {
          return method.replaceAll('_', ' ');
        }
    }
  }

  // Payment dialogs - reuse logic from old payments screen
  Future<void> _showAddPayment(
    BuildContext context,
    List<Student> students,
    String? schoolId,
  ) async {
    Student selectedStudent = students.first;
    final amountController = TextEditingController();
    final hoursController = TextEditingController();
    String method = 'cash';
    String paidTo = 'instructor';
    bool saving = false;
    final customMethods = List<CustomPaymentMethod>.from(
      widget.instructor.instructorSettings?.customPaymentMethods ?? [],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_card_rounded,
                              color: AppTheme.success),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Payment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Record a new payment',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Student>(
                            value: selectedStudent,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: students
                                .map((student) => DropdownMenuItem(
                                      value: student,
                                      child: Text(student.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedStudent = value);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount (£)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: amountController,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.currency_pound),
                                        hintText: '0.00',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hours',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: hoursController,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.schedule_outlined),
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMethodChip('cash', 'Cash',
                                  Icons.payments_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('bank_transfer', 'Bank',
                                  Icons.account_balance_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('card', 'Card',
                                  Icons.credit_card_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('other', 'Other',
                                  Icons.receipt_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              ...customMethods.map((m) => _buildMethodChip(
                                    m.id,
                                    m.label,
                                    Icons.payments_outlined,
                                    method,
                                    (val) => setDialogState(() => method = val),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Paid To',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaidToOption(
                                  'instructor',
                                  'Instructor',
                                  Icons.person_outline,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaidToOption(
                                  'school',
                                  'School',
                                  Icons.business_outlined,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border:
                          Border(top: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final amount =
                                        double.tryParse(amountController.text) ??
                                            0;
                                    final hours =
                                        double.tryParse(hoursController.text) ?? 0;
                                    setDialogState(() => saving = true);
                                    final payment = Payment(
                                      id: '',
                                      instructorId: widget.instructor.id,
                                      studentId: selectedStudent.id,
                                      schoolId: schoolId,
                                      amount: amount,
                                      currency: 'GBP',
                                      method: method,
                                      paidTo: paidTo,
                                      hoursPurchased: hours,
                                      createdAt: DateTime.now(),
                                    );
                                    await _firestoreService.addPayment(
                                      payment: payment,
                                      studentId: selectedStudent.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: saving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text('Save Payment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditPayment(BuildContext context, Payment payment) async {
    final amountController =
        TextEditingController(text: payment.amount.toStringAsFixed(2));
    final hoursController =
        TextEditingController(text: payment.hoursPurchased.toStringAsFixed(1));
    String method = payment.method;
    String paidTo = payment.paidTo;
    bool saving = false;
    final customMethods = List<CustomPaymentMethod>.from(
      widget.instructor.instructorSettings?.customPaymentMethods ?? [],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _getMethodBackgroundColor(payment.method),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getMethodIcon(payment.method),
                            color: _getMethodColor(payment.method),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Payment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Update payment details',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: amountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (£)',
                                    prefixIcon: Icon(Icons.currency_pound),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: hoursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hours',
                                    prefixIcon: Icon(Icons.schedule_outlined),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMethodChip('cash', 'Cash',
                                  Icons.payments_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('bank_transfer', 'Bank',
                                  Icons.account_balance_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('card', 'Card',
                                  Icons.credit_card_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              _buildMethodChip('other', 'Other',
                                  Icons.receipt_outlined, method, (val) {
                                setDialogState(() => method = val);
                              }),
                              ...customMethods.map((m) => _buildMethodChip(
                                    m.id,
                                    m.label,
                                    Icons.payments_outlined,
                                    method,
                                    (val) => setDialogState(() => method = val),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Paid To',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaidToOption(
                                  'instructor',
                                  'Instructor',
                                  Icons.person_outline,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaidToOption(
                                  'school',
                                  'School',
                                  Icons.business_outlined,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border:
                          Border(top: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _confirmDeletePayment(context, payment),
                          icon: const Icon(Icons.delete_outline_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final amount =
                                        double.tryParse(amountController.text) ??
                                            0;
                                    final hours =
                                        double.tryParse(hoursController.text) ?? 0;
                                    setDialogState(() => saving = true);
                                    final updated = Payment(
                                      id: payment.id,
                                      instructorId: payment.instructorId,
                                      studentId: payment.studentId,
                                      schoolId: payment.schoolId,
                                      amount: amount,
                                      currency: payment.currency,
                                      method: method,
                                      paidTo: paidTo,
                                      hoursPurchased: hours,
                                      createdAt: payment.createdAt,
                                    );
                                    await _firestoreService.updatePayment(
                                      payment: updated,
                                      previousHours: payment.hoursPurchased,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: saving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePayment(BuildContext context, Payment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppTheme.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Delete payment?')),
            ],
          ),
          content: const Text(
              'This will remove the payment and restore hours to the student balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _firestoreService.deletePayment(payment);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildMethodChip(
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? _getMethodBackgroundColor(value) : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _getMethodColor(value) : AppTheme.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? _getMethodColor(value) : AppTheme.neutral500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _getMethodColor(value) : AppTheme.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidToOption(
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.neutral500,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.tabController,
    required this.colorScheme,
  });

  final TabController tabController;
  final ColorScheme colorScheme;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: colorScheme.surface,
      child: TabBar(
        controller: tabController,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colorScheme.outlineVariant,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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

// Data classes for expected income
class _ExpectedIncomeData {
  _ExpectedIncomeData({
    required this.totalAmount,
    required this.byStudent,
  });

  final double totalAmount;
  final List<_StudentExpectedIncome> byStudent;
}

class _StudentExpectedIncome {
  _StudentExpectedIncome({
    required this.studentId,
    required this.studentName,
    required this.lessonCount,
    required this.totalHours,
    required this.hourlyRate,
    required this.expectedAmount,
  });

  final String studentId;
  final String studentName;
  final int lessonCount;
  final double totalHours;
  final double hourlyRate;
  final double expectedAmount;
}
