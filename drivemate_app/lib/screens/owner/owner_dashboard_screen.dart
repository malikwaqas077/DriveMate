import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/school_instructor.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_view.dart';
import 'owner_access_requests_screen.dart';
import 'owner_instructors_screen.dart';

/// Owner dashboard with key stats and charts.
class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key, required this.owner});

  final UserProfile owner;
  static final FirestoreService _firestoreService = FirestoreService();

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
          return const LoadingView(message: 'Loading dashboard...');
        }
        final links = linkSnapshot.data ?? [];
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
            final pendingAccess =
                requests.where((r) => r.status == 'pending').length;
            return StreamBuilder<List<Payment>>(
              stream: _firestoreService.streamPaymentsForSchool(schoolId),
              builder: (context, paymentsSnapshot) {
                if (paymentsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading...');
                }
                final payments = paymentsSnapshot.data ?? [];
                final now = DateTime.now();
                final monthStart = DateTime(now.year, now.month, 1);
                final monthEnd = DateTime(now.year, now.month + 1, 1);
                final monthToSchool =
                    _sumPaidTo(payments, monthStart, monthEnd, 'school');

                return _DashboardCharts(
                  owner: owner,
                  links: links,
                  payments: payments,
                  monthToSchool: monthToSchool,
                  pendingAccess: pendingAccess,
                );
              },
            );
          },
        );
      },
    );
  }

  double _sumPaidTo(List<Payment> payments, DateTime start, DateTime end,
      String paidTo) {
    return payments
        .where(
          (p) =>
              p.paidTo == paidTo &&
              !p.createdAt.isBefore(start) &&
              p.createdAt.isBefore(end),
        )
        .fold(0.0, (sum, p) => sum + p.amount);
  }
}

class _DashboardCharts extends StatelessWidget {
  const _DashboardCharts({
    required this.owner,
    required this.links,
    required this.payments,
    required this.monthToSchool,
    required this.pendingAccess,
  });

  final UserProfile owner;
  final List<SchoolInstructor> links;
  final List<Payment> payments;
  final double monthToSchool;
  final int pendingAccess;

  static const int _monthsToShow = 6;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    return FutureBuilder<_ChartData>(
      future: _loadChartData(links, payments, now),
      builder: (context, snapshot) {
        final chartData = snapshot.data;
        final isLoading = !snapshot.hasData;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(context, 'Overview'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_rounded,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withOpacity(0.1),
                    label: 'Instructors',
                    value: '${links.length}',
                    onTap: () => _goToInstructors(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.school_rounded,
                    iconColor: AppTheme.secondary,
                    iconBgColor: AppTheme.secondaryLight,
                    label: 'Students',
                    value: chartData?.totalStudents.toString() ?? '...',
                    onTap: () => _goToInstructors(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppTheme.success,
                    iconBgColor: AppTheme.successLight,
                    label: 'Revenue this month',
                    value: '£${monthToSchool.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_month_rounded,
                    iconColor: AppTheme.info,
                    iconBgColor: AppTheme.infoLight,
                    label: 'Lessons this month',
                    value: chartData?.monthLessons.toString() ?? '0',
                  ),
                ),
              ],
            ),
            if (pendingAccess > 0) ...[
              const SizedBox(height: 12),
              _PendingAccessCard(
                count: pendingAccess,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OwnerAccessRequestsScreen(owner: owner),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            _sectionTitle(context, 'Students per month'),
            const SizedBox(height: 8),
            Text(
              'New students added each month',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _StudentsChart(monthlyStudents: chartData!.monthlyStudents),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Revenue per month'),
            const SizedBox(height: 8),
            Text(
              'School revenue (payments to school)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _RevenueChart(monthlyRevenue: chartData!.monthlyRevenue),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Lessons per month'),
            const SizedBox(height: 8),
            Text(
              'Completed lessons across all instructors',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _LessonsChart(monthlyLessons: chartData!.monthlyLessons),
            ),
          ],
        );
      },
    );
  }

  Future<_ChartData> _loadChartData(
    List<SchoolInstructor> links,
    List<Payment> payments,
    DateTime now,
  ) async {
    final monthlyStudents = List<int>.filled(_monthsToShow, 0);
    final monthlyRevenue = List<double>.filled(_monthsToShow, 0);
    final monthlyLessons = List<int>.filled(_monthsToShow, 0);

    int totalStudents = 0;

    for (var i = 0; i < _monthsToShow; i++) {
      final m = now.month - i;
      final y = now.year;
      int month = m;
      int year = y;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);

      monthlyRevenue[_monthsToShow - 1 - i] = payments
          .where(
            (p) =>
                p.paidTo == 'school' &&
                !p.createdAt.isBefore(start) &&
                p.createdAt.isBefore(end),
          )
          .fold(0.0, (sum, p) => sum + p.amount);
    }

    for (final link in links) {
      final students = await OwnerDashboardScreen._firestoreService
          .streamStudents(link.instructorId)
          .first;
      totalStudents += students.length;

      for (final s in students) {
        final created = s.createdAt;
        if (created != null) {
          for (var i = 0; i < _monthsToShow; i++) {
            final m = now.month - i;
            final yr = now.year;
            int month = m;
            int year = yr;
            while (month <= 0) {
              month += 12;
              year -= 1;
            }
            final start = DateTime(year, month, 1);
            final end = DateTime(year, month + 1, 1);
            if (!created.isBefore(start) && created.isBefore(end)) {
              monthlyStudents[_monthsToShow - 1 - i]++;
              break;
            }
          }
        }
      }

      final lessons = await OwnerDashboardScreen._firestoreService
          .streamLessonsForInstructor(link.instructorId)
          .first;

      for (var i = 0; i < _monthsToShow; i++) {
        final m = now.month - i;
        final yr = now.year;
        int month = m;
        int year = yr;
        while (month <= 0) {
          month += 12;
          year -= 1;
        }
        final start = DateTime(year, month, 1);
        final end = DateTime(year, month + 1, 1);
        final count = lessons
            .where((l) =>
                l.status == 'completed' &&
                !l.startAt.isBefore(start) &&
                l.startAt.isBefore(end))
            .length;
        monthlyLessons[_monthsToShow - 1 - i] += count;
      }
    }

    final monthLessonsCount = monthlyLessons.isNotEmpty
        ? monthlyLessons.last
        : 0;

    return _ChartData(
      monthlyStudents: monthlyStudents,
      monthlyRevenue: monthlyRevenue,
      monthlyLessons: monthlyLessons,
      totalStudents: totalStudents,
      monthLessons: monthLessonsCount,
    );
  }

  void _goToInstructors(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerInstructorsScreen(owner: owner),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _ChartData {
  _ChartData({
    required this.monthlyStudents,
    required this.monthlyRevenue,
    required this.monthlyLessons,
    required this.totalStudents,
    required this.monthLessons,
  });

  final List<int> monthlyStudents;
  final List<double> monthlyRevenue;
  final List<int> monthlyLessons;
  final int totalStudents;
  final int monthLessons;
}

class _StudentsChart extends StatelessWidget {
  const _StudentsChart({required this.monthlyStudents});

  final List<int> monthlyStudents;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spots = monthlyStudents.asMap().entries.map((e) {
      final i = e.key;
      final m = now.month - (5 - i);
      final y = now.year;
      int month = m;
      int year = y;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      return FlSpot(i.toDouble(), e.value.toDouble());
    }).toList();

    final maxY = (monthlyStudents.isEmpty
        ? 5.0
        : (monthlyStudents.reduce((a, b) => a > b ? a : b) + 1).toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxY < 5 ? 5.0 : maxY).toDouble(),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= 6) return const SizedBox();
                    final m = now.month - (5 - i);
                    final y = now.year;
                    int month = m;
                    int year = y;
                    while (month <= 0) {
                      month += 12;
                      year -= 1;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM').format(DateTime(year, month)),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: spots.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.y,
                    color: AppTheme.primary,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.monthlyRevenue});

  final List<double> monthlyRevenue;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spots = monthlyRevenue.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    final maxVal = monthlyRevenue.isEmpty
        ? 100.0
        : monthlyRevenue.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal < 50 ? 100.0 : (maxVal * 1.2)).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, meta) => Text(
                    '£${v.toInt()}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= 6) return const SizedBox();
                    final m = now.month - (5 - i);
                    final y = now.year;
                    int month = m;
                    int year = y;
                    while (month <= 0) {
                      month += 12;
                      year -= 1;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM').format(DateTime(year, month)),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: spots.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.y,
                    color: AppTheme.success,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

class _LessonsChart extends StatelessWidget {
  const _LessonsChart({required this.monthlyLessons});

  final List<int> monthlyLessons;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spots = monthlyLessons.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();

    final maxY = monthlyLessons.isEmpty
        ? 10.0
        : (monthlyLessons.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxY < 5 ? 10.0 : maxY).toDouble(),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= 6) return const SizedBox();
                    final m = now.month - (5 - i);
                    final y = now.year;
                    int month = m;
                    int year = y;
                    while (month <= 0) {
                      month += 12;
                      year -= 1;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM').format(DateTime(year, month)),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: spots.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.y,
                    color: AppTheme.info,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAccessCard extends StatelessWidget {
  const _PendingAccessCard({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppTheme.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count pending access request${count == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to review',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
