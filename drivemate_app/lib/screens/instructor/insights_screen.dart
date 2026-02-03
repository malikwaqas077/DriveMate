import 'dart:math' as math;
import 'dart:ui' as ui;

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

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedPeriod = 'month'; // week, month, year

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: _firestoreService.streamLessonsForInstructor(widget.instructor.id),
      builder: (context, lessonsSnapshot) {
        if (lessonsSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading insights...');
        }
        final lessons = lessonsSnapshot.data ?? [];

        return StreamBuilder<List<Student>>(
          stream: _firestoreService.streamStudents(widget.instructor.id),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading...');
            }
            final students = studentsSnapshot.data ?? [];

            return StreamBuilder<List<CancellationRequest>>(
              stream: _firestoreService
                  .streamCancellationRequestsForInstructor(widget.instructor.id),
              builder: (context, cancellationsSnapshot) {
                if (cancellationsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading...');
                }
                final cancellations = cancellationsSnapshot.data ?? [];

                return StreamBuilder<List<Payment>>(
                  stream: _firestoreService
                      .streamPaymentsForInstructor(widget.instructor.id),
                  builder: (context, paymentsSnapshot) {
                    if (paymentsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView(message: 'Loading...');
                    }
                    final payments = paymentsSnapshot.data ?? [];

                    return _buildContent(
                      context,
                      lessons,
                      students,
                      cancellations,
                      payments,
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
    List<Lesson> lessons,
    List<Student> students,
    List<CancellationRequest> cancellations,
    List<Payment> payments,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Get date range based on selected period
    final (periodStart, periodEnd, prevStart, prevEnd) =
        _getDateRanges(now, _selectedPeriod);

    // Calculate metrics
    final periodEarnings = _sumPaymentsInRange(payments, periodStart, periodEnd);
    final prevEarnings = _sumPaymentsInRange(payments, prevStart, prevEnd);
    final earningsChange = prevEarnings > 0
        ? ((periodEarnings - prevEarnings) / prevEarnings * 100)
        : (periodEarnings > 0 ? 100.0 : 0.0);

    final periodLessons = _lessonsInRange(lessons, periodStart, periodEnd);
    final prevLessons = _lessonsInRange(lessons, prevStart, prevEnd);

    // Count lessons as completed if:
    // 1. Explicitly marked as 'completed', OR
    // 2. Status is 'scheduled' but the lesson end time is in the past
    bool isLessonCompleted(Lesson l) {
      if (l.status == 'completed') return true;
      if (l.status == 'cancelled') return false;
      // If scheduled but past, consider it completed
      final endAt = l.startAt.add(Duration(minutes: (l.durationHours * 60).round()));
      return endAt.isBefore(now);
    }

    final completedCount = periodLessons.where(isLessonCompleted).length;
    final scheduledCount = periodLessons
        .where((l) => l.status == 'scheduled' && !isLessonCompleted(l))
        .length;
    final cancelledCount =
        periodLessons.where((l) => l.status == 'cancelled').length;
    final totalLessonCount = periodLessons.length;

    final prevCompletedCount = prevLessons.where(isLessonCompleted).length;

    final completedHours = periodLessons
        .where(isLessonCompleted)
        .fold<double>(0, (sum, l) => sum + l.durationHours);

    // Completion rate
    final totalNonScheduled =
        periodLessons.where((l) => l.status != 'scheduled').length;
    final completionRate =
        totalNonScheduled > 0 ? (completedCount / totalNonScheduled * 100) : 0.0;

    // Cancellation rate
    final cancellationRate =
        totalLessonCount > 0 ? (cancelledCount / totalLessonCount * 100) : 0.0;

    // Student metrics
    final activeStudents = students.where((s) => s.status == 'active').length;
    final testReadyStudents =
        students.where((s) => s.status == 'test_ready').length;
    final passedStudents = students.where((s) => s.status == 'passed').length;

    // Earnings trend (last 6 periods)
    final earningsTrend = _calculateEarningsTrend(payments, now, _selectedPeriod);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          _buildPeriodSelector(context),
          const SizedBox(height: 16),

          // Earnings trend chart
          _buildEarningsTrendCard(
            context,
            periodEarnings,
            earningsChange,
            earningsTrend,
          ),
          const SizedBox(height: 16),

          // Performance metrics row
          _buildPerformanceMetrics(
            context,
            completedCount,
            completedHours,
            completionRate,
            cancellationRate,
          ),
          const SizedBox(height: 16),

          // Lessons breakdown
          _buildLessonsBreakdown(
            context,
            completedCount,
            scheduledCount,
            cancelledCount,
            prevCompletedCount,
          ),
          const SizedBox(height: 16),

          // Student overview
          _buildStudentOverview(
            context,
            students.length,
            activeStudents,
            testReadyStudents,
            passedStudents,
          ),
          const SizedBox(height: 16),

          // School balance (if linked)
          if (widget.instructor.schoolId != null &&
              widget.instructor.schoolId!.isNotEmpty)
            _buildSchoolBalanceCard(context, payments, periodStart, periodEnd),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodChip('week', 'Week'),
          _buildPeriodChip('month', 'Month'),
          _buildPeriodChip('year', 'Year'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsTrendCard(
    BuildContext context,
    double currentEarnings,
    double change,
    List<_TrendPoint> trend,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = change >= 0;
    final periodLabel = _selectedPeriod == 'week'
        ? 'This week'
        : _selectedPeriod == 'month'
            ? 'This month'
            : 'This year';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    periodLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '£${currentEarnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppTheme.successLight
                      : AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isPositive ? AppTheme.success : AppTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: _EarningsChart(trend: trend, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(
    BuildContext context,
    int completedCount,
    double completedHours,
    double completionRate,
    double cancellationRate,
  ) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Lessons',
            value: completedCount.toString(),
            subtitle: 'Completed',
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Hours',
            value: completedHours.toStringAsFixed(1),
            subtitle: 'Taught',
            icon: Icons.schedule_rounded,
            color: AppTheme.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Completion',
            value: '${completionRate.toStringAsFixed(0)}%',
            subtitle: 'Rate',
            icon: Icons.task_alt_rounded,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonsBreakdown(
    BuildContext context,
    int completed,
    int scheduled,
    int cancelled,
    int prevCompleted,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = completed + scheduled + cancelled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Lessons Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (completed > 0)
                    Expanded(
                      flex: completed,
                      child: Container(height: 8, color: AppTheme.success),
                    ),
                  if (scheduled > 0)
                    Expanded(
                      flex: scheduled,
                      child: Container(height: 8, color: AppTheme.info),
                    ),
                  if (cancelled > 0)
                    Expanded(
                      flex: cancelled,
                      child: Container(height: 8, color: AppTheme.warning),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LessonStat(
                  label: 'Completed',
                  count: completed,
                  color: AppTheme.success,
                  prevCount: prevCompleted,
                ),
              ),
              Expanded(
                child: _LessonStat(
                  label: 'Scheduled',
                  count: scheduled,
                  color: AppTheme.info,
                ),
              ),
              Expanded(
                child: _LessonStat(
                  label: 'Cancelled',
                  count: cancelled,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentOverview(
    BuildContext context,
    int total,
    int active,
    int testReady,
    int passed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_rounded,
                    color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$total total',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StudentStatChip(
                  label: 'Active',
                  count: active,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudentStatChip(
                  label: 'Test Ready',
                  count: testReady,
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudentStatChip(
                  label: 'Passed',
                  count: passed,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolBalanceCard(
    BuildContext context,
    List<Payment> payments,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final periodPayments = payments
        .where((p) =>
            !p.createdAt.isBefore(periodStart) &&
            p.createdAt.isBefore(periodEnd))
        .toList();

    final paidToSchool = periodPayments
        .where((p) => p.paidTo == 'school')
        .fold<double>(0, (sum, p) => sum + p.amount);
    final paidToInstructor = periodPayments
        .where((p) => p.paidTo == 'instructor')
        .fold<double>(0, (sum, p) => sum + p.amount);

    return StreamBuilder(
      stream: _firestoreService.streamInstructorSchoolLink(widget.instructor.id),
      builder: (context, linkSnapshot) {
        final link = linkSnapshot.data;
        if (link == null) return const SizedBox.shrink();

        final feeDue = _selectedPeriod == 'week' && link.feeFrequency == 'week'
            ? link.feeAmount
            : _selectedPeriod == 'month' && link.feeFrequency == 'month'
                ? link.feeAmount
                : 0.0;

        final netBalance = paidToSchool - feeDue;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business_rounded,
                        color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'School Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _BalanceRow(
                  label: 'Collected (to school)',
                  amount: paidToSchool,
                  color: AppTheme.success),
              const SizedBox(height: 8),
              _BalanceRow(
                  label: 'Collected (to you)',
                  amount: paidToInstructor,
                  color: AppTheme.info),
              if (feeDue > 0) ...[
                const SizedBox(height: 8),
                _BalanceRow(
                    label: 'Fee due to school', amount: -feeDue, color: AppTheme.error),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net (school owes you)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '£${netBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: netBalance >= 0 ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods
  (DateTime, DateTime, DateTime, DateTime) _getDateRanges(
      DateTime now, String period) {
    switch (period) {
      case 'week':
        final weekStart = _startOfWeek(now);
        final weekEnd = weekStart.add(const Duration(days: 7));
        final prevStart = weekStart.subtract(const Duration(days: 7));
        final prevEnd = weekStart;
        return (weekStart, weekEnd, prevStart, prevEnd);
      case 'year':
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year + 1, 1, 1);
        final prevStart = DateTime(now.year - 1, 1, 1);
        final prevEnd = yearStart;
        return (yearStart, yearEnd, prevStart, prevEnd);
      default: // month
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        final prevStart = DateTime(now.year, now.month - 1, 1);
        final prevEnd = monthStart;
        return (monthStart, monthEnd, prevStart, prevEnd);
    }
  }

  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  double _sumPaymentsInRange(
      List<Payment> payments, DateTime start, DateTime end) {
    return payments
        .where(
            (p) => !p.createdAt.isBefore(start) && p.createdAt.isBefore(end))
        .fold(0, (sum, p) => sum + p.amount);
  }

  List<Lesson> _lessonsInRange(
      List<Lesson> lessons, DateTime start, DateTime end) {
    return lessons
        .where((l) => !l.startAt.isBefore(start) && l.startAt.isBefore(end))
        .toList();
  }

  List<_TrendPoint> _calculateEarningsTrend(
      List<Payment> payments, DateTime now, String period) {
    final points = <_TrendPoint>[];
    final count = 6;

    for (var i = count - 1; i >= 0; i--) {
      late DateTime start, end;
      late String label;

      switch (period) {
        case 'week':
          final weekStart = _startOfWeek(now);
          start = weekStart.subtract(Duration(days: 7 * i));
          end = start.add(const Duration(days: 7));
          label = DateFormat('d MMM').format(start);
          break;
        case 'year':
          start = DateTime(now.year - i, 1, 1);
          end = DateTime(now.year - i + 1, 1, 1);
          label = DateFormat('yyyy').format(start);
          break;
        default: // month
          start = DateTime(now.year, now.month - i, 1);
          end = DateTime(now.year, now.month - i + 1, 1);
          label = DateFormat('MMM').format(start);
      }

      final amount = _sumPaymentsInRange(payments, start, end);
      points.add(_TrendPoint(label: label, value: amount));
    }

    return points;
  }
}

class _TrendPoint {
  _TrendPoint({required this.label, required this.value});
  final String label;
  final double value;
}

class _EarningsChart extends StatelessWidget {
  const _EarningsChart({required this.trend, required this.color});

  final List<_TrendPoint> trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxValue = trend.map((t) => t.value).reduce(math.max);
    final minValue = trend.map((t) => t.value).reduce(math.min);
    final range = maxValue - minValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final pointSpacing = width / (trend.length - 1);

        return CustomPaint(
          size: Size(width, height),
          painter: _ChartPainter(
            trend: trend,
            color: color,
            maxValue: maxValue,
            minValue: minValue,
            range: range,
            pointSpacing: pointSpacing,
            labelColor: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.trend,
    required this.color,
    required this.maxValue,
    required this.minValue,
    required this.range,
    required this.pointSpacing,
    required this.labelColor,
  });

  final List<_TrendPoint> trend;
  final Color color;
  final double maxValue;
  final double minValue;
  final double range;
  final double pointSpacing;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 20; // Leave space for labels
    final points = <Offset>[];

    // Calculate points
    for (var i = 0; i < trend.length; i++) {
      final x = i * pointSpacing;
      final normalizedY = range > 0
          ? (trend[i].value - minValue) / range
          : 0.5;
      final y = chartHeight - (normalizedY * chartHeight * 0.8) - (chartHeight * 0.1);
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    final fillPath = Path();
    fillPath.moveTo(0, chartHeight);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width - pointSpacing, chartHeight);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.3),
        color.withOpacity(0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[i].dx, points[i].dy);
      } else {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Draw points
    final pointPaint = Paint()..color = color;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
      canvas.drawCircle(point, 4, pointBorderPaint);
    }

    // Draw labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    for (var i = 0; i < trend.length; i++) {
      textPainter.text = TextSpan(
        text: trend[i].label,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          points[i].dx - textPainter.width / 2,
          size.height - 14,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStat extends StatelessWidget {
  const _LessonStat({
    required this.label,
    required this.count,
    required this.color,
    this.prevCount,
  });

  final String label;
  final int count;
  final Color color;
  final int? prevCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final change = prevCount != null ? count - prevCount! : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (change != null && change != 0) ...[
              const SizedBox(width: 4),
              Text(
                '${change > 0 ? '+' : ''}$change',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: change > 0 ? AppTheme.success : AppTheme.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StudentStatChip extends StatelessWidget {
  const _StudentStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
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
          '${amount < 0 ? '-' : ''}£${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
