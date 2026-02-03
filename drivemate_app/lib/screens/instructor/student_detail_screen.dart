import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.instructorId,
  });

  final String studentId;
  final String studentName;
  final String? instructorId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentFinanceSummary {
  const _StudentFinanceSummary({
    required this.totalPaidHours,
    required this.totalPaidAmount,
    required this.completedHours,
    required this.upcomingHours,
    required this.completedLessons,
    required this.upcomingLessons,
    required this.totalLessons,
    required this.availableCredit,
  });

  final double totalPaidHours;
  final double totalPaidAmount;
  final double completedHours;
  final double upcomingHours;
  final List<Lesson> completedLessons;
  final List<Lesson> upcomingLessons;
  final int totalLessons;
  final double availableCredit;
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(symbol: '£');
  final ScrollController _scrollController = ScrollController();

  String? _editingPaymentId;
  final Map<String, TextEditingController> _paymentAmountControllers = {};
  final Map<String, TextEditingController> _paymentHoursControllers = {};

  bool _loginDetailsExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _paymentAmountControllers.values) {
      controller.dispose();
    }
    for (final controller in _paymentHoursControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        elevation: 0,
        actions: [
          StreamBuilder<Student?>(
            stream: _firestoreService.streamStudentById(widget.studentId),
            builder: (context, snapshot) {
              final student = snapshot.data;
              if (student == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditProfile(context, student),
                tooltip: 'Edit Profile',
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Student?>(
        stream: _firestoreService.streamStudentById(widget.studentId),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading student...');
          }
          final student = studentSnapshot.data;
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          return StreamBuilder<List<Lesson>>(
            stream: _firestoreService.streamLessonsForStudent(widget.studentId),
            builder: (context, lessonSnapshot) {
              if (lessonSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading lessons...');
              }
              final lessons = lessonSnapshot.data ?? [];
              return StreamBuilder<List<Payment>>(
                stream: _firestoreService.streamPaymentsForStudent(widget.studentId),
                builder: (context, paymentSnapshot) {
                  if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(message: 'Loading payments...');
                  }
                  final payments = paymentSnapshot.data ?? [];
                  final summary = _buildFinanceSummary(lessons, payments);

                  return ListView(
                    key: const ValueKey('student_detail_scroll'),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderSection(context, student),
                      const SizedBox(height: 16),
                      _buildQuickStats(context, student, summary),
                      const SizedBox(height: 16),
                      _buildOverviewSection(context, student, summary, payments),
                      const SizedBox(height: 16),
                      _buildUpcomingLessonsSection(context, summary),
                      const SizedBox(height: 16),
                      _buildCollapsibleLoginCard(context),
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

  _StudentFinanceSummary _buildFinanceSummary(
    List<Lesson> lessons,
    List<Payment> payments,
  ) {
    final now = DateTime.now();
    final activeLessons = lessons.where((lesson) => lesson.status != 'cancelled').toList();
    final completedLessons = activeLessons.where((lesson) => !lesson.startAt.isAfter(now)).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final upcomingLessons = activeLessons.where((lesson) => lesson.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final completedHours = completedLessons.fold<double>(
      0,
      (total, lesson) => total + lesson.durationHours,
    );
    final upcomingHours = upcomingLessons.fold<double>(
      0,
      (total, lesson) => total + lesson.durationHours,
    );
    final totalPaidHours = payments.fold<double>(
      0,
      (total, payment) => total + payment.hoursPurchased,
    );
    final totalPaidAmount = payments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final availableCredit = totalPaidHours - completedHours;

    return _StudentFinanceSummary(
      totalPaidHours: totalPaidHours,
      totalPaidAmount: totalPaidAmount,
      completedHours: completedHours,
      upcomingHours: upcomingHours,
      completedLessons: completedLessons,
      upcomingLessons: upcomingLessons,
      totalLessons: activeLessons.length,
      availableCredit: availableCredit,
    );
  }

  Widget _buildHeaderSection(BuildContext context, Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: context.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _getInitials(student.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (student.phone != null && student.phone!.isNotEmpty)
                  Text(
                    student.phone!,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (student.phone != null && student.phone!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _makePhoneCall(student.phone!),
                  icon: const Icon(Icons.phone, color: AppTheme.primary),
                  tooltip: 'Call',
                ),
                IconButton(
                  onPressed: () => _sendSMS(student.phone!),
                  icon: const Icon(Icons.message, color: AppTheme.primary),
                  tooltip: 'Message',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    Student student,
    _StudentFinanceSummary summary,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = summary.availableCredit < 0
        ? AppTheme.error
        : summary.availableCredit > 0
            ? AppTheme.success
            : colorScheme.onSurfaceVariant;
    final upcomingColor = summary.upcomingHours > 0
        ? AppTheme.info
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.availableCredit.toStringAsFixed(1)} hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: balanceColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.upcomingHours.toStringAsFixed(1)} hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: upcomingColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBackgroundColor(student.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    student.status[0].toUpperCase() + student.status.substring(1),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(student.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    Student student,
    _StudentFinanceSummary summary,
    List<Payment> payments,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCompletedLessons = summary.completedLessons.isNotEmpty;
    final hasPayments = payments.isNotEmpty;

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
          _buildSectionHeader(
            context,
            'Overview',
            Icons.insights_outlined,
            AppTheme.info,
            AppTheme.infoLight,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Completed',
                  value: '${summary.completedLessons.length}',
                  icon: Icons.event_available_rounded,
                  iconColor: AppTheme.success,
                  iconBgColor: AppTheme.successLight,
                  onTap: hasCompletedLessons
                      ? () => _showLessonsSheet(context, summary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Total Lessons',
                  value: '${summary.totalLessons}',
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppTheme.info,
                  iconBgColor: AppTheme.infoLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Total Spent',
                  value: _currencyFormat.format(summary.totalPaidAmount),
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFF8B5CF6).withOpacity(0.18),
                  onTap: () => _showPaymentsSheet(
                    context,
                    student,
                    payments,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Hourly Rate',
                  value: student.hourlyRate != null
                      ? '£${student.hourlyRate!.toStringAsFixed(0)}'
                      : 'N/A',
                  icon: Icons.speed_rounded,
                  iconColor: AppTheme.secondary,
                  iconBgColor: AppTheme.secondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  Widget _buildUpcomingLessonsSection(
    BuildContext context,
    _StudentFinanceSummary summary,
  ) {
    final upcoming = summary.upcomingLessons;
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
          _buildSectionHeader(
            context,
            'Upcoming Lessons',
            Icons.event_outlined,
            AppTheme.info,
            AppTheme.infoLight,
          ),
          const SizedBox(height: 16),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No upcoming lessons scheduled.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...upcoming.map((lesson) => _buildLessonItem(context, lesson)),
        ],
      ),
    );
  }

  void _showLessonsSheet(BuildContext context, _StudentFinanceSummary summary) {
    final upcoming = summary.upcomingLessons;
    final completed = summary.completedLessons;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final mediaQuery = MediaQuery.of(sheetContext);

        return Container(
          height: mediaQuery.size.height * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Lesson Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: (upcoming.isEmpty && completed.isEmpty)
                    ? Center(
                        child: Text(
                          'No lessons recorded yet.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (upcoming.isNotEmpty) ...[
                            Text(
                              'Upcoming',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...upcoming.map((lesson) => _buildLessonItem(sheetContext, lesson)),
                            const SizedBox(height: 20),
                          ],
                          if (completed.isNotEmpty) ...[
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...completed.map((lesson) => _buildLessonItem(sheetContext, lesson)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentsSheet(
    BuildContext context,
    Student student,
    List<Payment> payments,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final mediaQuery = MediaQuery.of(sheetContext);
        final instructorId = widget.instructorId ?? student.instructorId;

        return Container(
          height: mediaQuery.size.height * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Payments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showAddPayment(context, student);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Payment'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<UserProfile?>(
                  stream: instructorId != null
                      ? _firestoreService.streamUserProfile(instructorId)
                      : null,
                  builder: (streamContext, instructorSnapshot) {
                    final instructor = instructorSnapshot.data;
                    if (payments.isEmpty) {
                      return Center(
                        child: Text(
                          'No payments recorded yet.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: payments.length,
                      itemBuilder: (_, index) {
                        final payment = payments[index];
                        return _buildPaymentItem(
                          streamContext,
                          payment,
                          instructor: instructor,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLessonTimeRange(Lesson lesson) {
    final start = lesson.startAt;
    final minutes = (lesson.durationHours * 60).round();
    final end = start.add(Duration(minutes: minutes));
    final formatter = DateFormat('HH:mm');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  Widget _buildLessonTypeBadge(String lessonType) {
    final textColor = switch (lessonType) {
      'mock_test' => const Color(0xFF5B21B6),
      'test' => const Color(0xFF1D4ED8),
      _ => AppTheme.secondaryDark,
    };
    final bgColor = switch (lessonType) {
      'mock_test' => const Color(0xFFEDE9FE),
      'test' => AppTheme.infoLight,
      _ => AppTheme.secondaryLight,
    };
    final label = switch (lessonType) {
      'mock_test' => 'Mock Test',
      'test' => 'Test',
      _ => 'Lesson',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildLessonItem(BuildContext context, Lesson lesson) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeRange = _formatLessonTimeRange(lesson);
    final isPast = lesson.startAt.isBefore(DateTime.now());
    final reflection = lesson.studentReflection?.trim();
    final hasReflection = reflection != null && reflection.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
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
              // Date block – same as student app: day number + month
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isPast
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(lesson.startAt),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isPast ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(lesson.startAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPast ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Day, time, duration – aligned like student app
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE').format(lesson.startAt),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        _buildLessonTypeBadge(lesson.lessonType),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeRange,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lesson.durationHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPast && hasReflection) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.warning),
                      const SizedBox(width: 6),
                      Text(
                        'Student Reflection',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reflection!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color iconColor,
    Color iconBgColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = colorScheme.brightness == Brightness.dark
        ? const Color(0xFFE6E1E5)
        : colorScheme.onSurface;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileExpandableSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool expanded,
    required ValueChanged<bool> onExpandedChanged,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpandedChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildCollapsibleLoginCard(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.streamUserProfileByStudentId(widget.studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading login...');
        }
        final profile = snapshot.data;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            initiallyExpanded: _loginDetailsExpanded,
            onExpansionChanged: (expanded) {
              setState(() => _loginDetailsExpanded = expanded);
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_outline, color: colorScheme.tertiary, size: 20),
            ),
            title: Text(
              'Login Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: profile == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No login created yet.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a login to allow student access.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                            _buildDetailRow(context, Icons.phone_outlined, 'Login Phone', profile.phone!),
                            const SizedBox(height: 16),
                          ] else ...[
                            _buildDetailRow(context, Icons.email_outlined, 'Login Email', profile.email),
                            const SizedBox(height: 16),
                          ],
                          if (profile.password != null && profile.password!.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.lock_outline, size: 20, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Password',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.password!,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _copyLoginDetails(context, profile),
                                    icon: const Icon(Icons.copy_outlined, size: 18),
                                    label: const Text('Copy'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _shareLoginDetails(context, profile),
                                    icon: const Icon(Icons.share_outlined, size: 18),
                                    label: const Text('Share'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Password not available.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyLoginDetails(BuildContext context, UserProfile profile) async {
    final identifier = profile.phone ?? profile.email;
    final password = profile.password ?? 'Not available';
    final message = 'Your DriveMate login details:\n${profile.phone != null ? "Phone Number" : "Email"}: $identifier\nPassword: $password';
    
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Login details copied'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _shareLoginDetails(BuildContext context, UserProfile profile) async {
    final identifier = profile.phone ?? profile.email;
    final password = profile.password ?? 'Not available';
    final message = 'Your DriveMate login details:\n${profile.phone != null ? "Phone Number" : "Email"}: $identifier\nPassword: $password';
    
    await Share.share(message, subject: 'DriveMate login details');
  }

  Widget _buildPaymentItem(BuildContext context, Payment payment, {UserProfile? instructor}) {
    final isEditing = _editingPaymentId == payment.id;

    if (!_paymentAmountControllers.containsKey(payment.id)) {
      _paymentAmountControllers[payment.id] = TextEditingController(
        text: payment.amount.toStringAsFixed(2),
      );
    }
    if (!_paymentHoursControllers.containsKey(payment.id)) {
      _paymentHoursControllers[payment.id] = TextEditingController(
        text: payment.hoursPurchased.toStringAsFixed(1),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outline),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getPaymentMethodIcon(payment.method, instructor: instructor),
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getPaymentMethodLabel(payment.method, instructor: instructor),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${payment.hoursPurchased.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(payment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currencyFormat.format(payment.amount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _startEditPayment(payment.id),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit payment',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paymentHoursControllers[payment.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      suffixText: 'h',
                      suffixStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: focusedBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _paymentAmountControllers[payment.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixText: '£',
                      prefixStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: focusedBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _savePayment(context, payment),
                  icon: const Icon(Icons.check, color: AppTheme.success),
                  tooltip: 'Save',
                ),
                IconButton(
                  onPressed: () => _cancelEditPayment(payment.id),
                  icon: const Icon(Icons.close, color: AppTheme.error),
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _startEditPayment(String paymentId) {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    setState(() {
      _editingPaymentId = paymentId;
    });
    // Restore scroll after layout: ListView is recreated inside StreamBuilder on setState,
    // so the new scroll position starts at 0. Restore in 2 frames so layout has settled.
    void restoreScroll() {
      if (_scrollController.hasClients && offset > 0) {
        _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreScroll());
    });
  }

  void _cancelEditPayment(String paymentId) {
    setState(() {
      _editingPaymentId = null;
    });
  }

  Future<void> _savePayment(BuildContext context, Payment payment) async {
    final amountController = _paymentAmountControllers[payment.id];
    final hoursController = _paymentHoursControllers[payment.id];
    if (amountController == null || hoursController == null) return;

    final newAmount = double.tryParse(amountController.text);
    final newHours = double.tryParse(hoursController.text);

    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please enter a valid amount'),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    if (newHours == null || newHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please enter valid hours'),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      final updatedPayment = Payment(
        id: payment.id,
        instructorId: payment.instructorId,
        studentId: payment.studentId,
        schoolId: payment.schoolId,
        amount: newAmount,
        currency: payment.currency,
        method: payment.method,
        paidTo: payment.paidTo,
        hoursPurchased: newHours,
        createdAt: payment.createdAt,
      );

      await _firestoreService.updatePayment(
        payment: updatedPayment,
        previousHours: payment.hoursPurchased,
      );

      setState(() {
        _editingPaymentId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Payment updated successfully'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating payment: $e')),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditProfile(BuildContext context, Student student) async {
    final nameController = TextEditingController(text: student.name);
    final emailController = TextEditingController(text: student.email ?? '');
    final phoneController = TextEditingController(text: student.phone ?? '');
    final licenseController = TextEditingController(text: student.licenseNumber ?? '');
    final addressController = TextEditingController(text: student.address ?? '');
    final rateController = TextEditingController(
      text: student.hourlyRate?.toStringAsFixed(2) ?? '',
    );
    String status = student.status;
    bool saving = false;
    bool optionalExpanded = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          _buildEditProfileExpandableSection(
                            context,
                            title: 'Additional details (optional)',
                            subtitle: 'Email, address, licence, rate, status',
                            expanded: optionalExpanded,
                            onExpandedChanged: (v) => setDialogState(() => optionalExpanded = v),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Address (optional)',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                    helperText: 'For navigation to pickup',
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: licenseController,
                                  decoration: const InputDecoration(
                                    labelText: 'License Number',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: rateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hourly Rate (£)',
                                    prefixIcon: Icon(Icons.payments_outlined),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: status,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    prefixIcon: Icon(Icons.flag_outlined),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'active', child: Text('Active')),
                                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                    DropdownMenuItem(value: 'passed', child: Text('Passed')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => status = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      ),
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
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Name is required'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => saving = true);
                                    try {
                                      final rateText = rateController.text.trim();
                                      final parsedRate = rateText.isEmpty
                                          ? null
                                          : double.tryParse(rateText);
                                      await _firestoreService.updateStudent(student.id, {
                                        'name': name,
                                        'email': emailController.text.trim().isEmpty
                                            ? null
                                            : emailController.text.trim(),
                                        'phone': phoneController.text.trim().isEmpty
                                            ? null
                                            : phoneController.text.trim(),
                                        'licenseNumber': licenseController.text.trim().isEmpty
                                            ? null
                                            : licenseController.text.trim(),
                                        'address': addressController.text.trim().isEmpty
                                            ? null
                                            : addressController.text.trim(),
                                        'hourlyRate': parsedRate,
                                        'status': status,
                                      });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle_outline,
                                                    color: Colors.white, size: 20),
                                                SizedBox(width: 12),
                                                Text('Profile updated successfully'),
                                              ],
                                            ),
                                            backgroundColor: AppTheme.success,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      setDialogState(() => saving = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to update: $error'),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save'),
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

  Future<void> _showAddPayment(BuildContext context, Student student) async {
    final amountController = TextEditingController();
    final hoursController = TextEditingController();
    String method = 'cash';
    String paidTo = 'instructor';
    bool saving = false;
    bool paymentDetailsExpanded = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Add Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.currency_pound, color: colorScheme.onSurfaceVariant),
                                        hintText: '0.00',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.schedule_outlined, color: colorScheme.onSurfaceVariant),
                                        hintText: '0',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildEditProfileExpandableSection(
                            context,
                            title: 'Payment details (optional)',
                            subtitle: 'Method and paid-to - tap to expand',
                            expanded: paymentDetailsExpanded,
                            onExpandedChanged: (v) => setDialogState(() => paymentDetailsExpanded = v),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Method',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StreamBuilder<UserProfile?>(
                                  stream: widget.instructorId != null
                                      ? _firestoreService.streamUserProfile(widget.instructorId!)
                                      : null,
                                  builder: (context, instructorSnapshot) {
                                    final instructor = instructorSnapshot.data;
                                    final allMethods = _getAllPaymentMethods(instructor: instructor);
                                    final theme = Theme.of(context);
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ...allMethods.map((m) => _buildMethodChip(
                                          context,
                                          m['id'] as String,
                                          m['label'] as String,
                                          m['icon'] as IconData,
                                          method,
                                          (val) => setDialogState(() => method = val),
                                        )),
                                        if (instructor != null)
                                          _buildAddNewPaymentMethodChip(
                                            context,
                                            theme.colorScheme,
                                            instructor,
                                            setDialogState,
                                            (newId) => setDialogState(() => method = newId),
                                          ),
                                      ],
                                    );
                                  },
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
                                        context,
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
                                        context,
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
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      ),
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
                                    final amount = double.tryParse(amountController.text) ?? 0;
                                    final hours = double.tryParse(hoursController.text) ?? 0;
                                    if (amount <= 0 || hours <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please enter valid amount and hours'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => saving = true);
                                    final payment = Payment(
                                      id: '',
                                      instructorId: widget.instructorId ?? student.instructorId,
                                      studentId: student.id,
                                      schoolId: student.schoolId,
                                      amount: amount,
                                      currency: 'GBP',
                                      method: method,
                                      paidTo: paidTo,
                                      hoursPurchased: hours,
                                      createdAt: DateTime.now(),
                                    );
                                    try {
                                      await _firestoreService.addPayment(
                                        payment: payment,
                                        studentId: student.id,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle_outline,
                                                    color: Colors.white, size: 20),
                                                SizedBox(width: 12),
                                                Text('Payment added successfully'),
                                              ],
                                            ),
                                            backgroundColor: AppTheme.success,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      setDialogState(() => saving = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to add payment: $error'),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildMethodChip(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _getMethodBackgroundColor(value) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _getMethodColor(value) : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? _getMethodColor(value) : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _getMethodColor(value) : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewPaymentMethodChip(
    BuildContext context,
    ColorScheme colorScheme,
    UserProfile instructor,
    StateSetter setDialogState,
    void Function(String newId) onAdded,
  ) {
    return GestureDetector(
      onTap: () async {
        final labelController = TextEditingController();
        final label = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New payment method'),
            content: TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Method name',
                hintText: 'e.g. PayPal, Venmo',
              ),
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, labelController.text.trim()),
                child: const Text('Add'),
              ),
            ],
          ),
        );
        if (label == null || label.isEmpty) return;
        final id = label.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (id.isEmpty) return;
        final customMethods = List<CustomPaymentMethod>.from(
          instructor.instructorSettings?.customPaymentMethods ?? [],
        );
        if (customMethods.any((m) => m.id == id)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This payment method already exists')),
            );
          }
          return;
        }
        customMethods.add(CustomPaymentMethod(id: id, label: label));
        final current = instructor.instructorSettings;
        final newSettings = InstructorSettings(
          cancellationRules: current?.cancellationRules,
          reminderHoursBefore: current?.reminderHoursBefore,
          notificationSettings: current?.notificationSettings,
          defaultNavigationApp: current?.defaultNavigationApp,
          lessonColors: current?.lessonColors,
          defaultCalendarView: current?.defaultCalendarView,
          customPaymentMethods: customMethods,
          customLessonTypes: current?.customLessonTypes,
        );
        await _firestoreService.updateUserProfile(instructor.id, {'instructorSettings': newSettings.toMap()});
        onAdded(id);
        setDialogState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outline, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Add new',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidToOption(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.success;
      case 'bank_transfer':
        return AppTheme.info;
      case 'card':
        return AppTheme.primary;
      default:
        return AppTheme.neutral500;
    }
  }

  Color _getMethodBackgroundColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.successLight;
      case 'bank_transfer':
        return AppTheme.infoLight;
      case 'card':
        return AppTheme.primaryLight.withOpacity(0.2);
      default:
        return AppTheme.neutral100;
    }
  }

  IconData _getPaymentMethodIcon(String method, {UserProfile? instructor}) {
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
        // Custom payment methods use the default icon
        return Icons.payments_outlined;
    }
  }

  String _getPaymentMethodLabel(String method, {UserProfile? instructor}) {
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
        // Check if it's a custom payment method
        if (instructor != null) {
          final customMethods = instructor.instructorSettings?.customPaymentMethods ?? [];
          try {
            final customMethod = customMethods.firstWhere((m) => m.id == method);
            return customMethod.label;
          } catch (_) {
            return method; // Fallback to method ID if not found
          }
        }
        return method;
    }
  }

  List<Map<String, dynamic>> _getAllPaymentMethods({UserProfile? instructor}) {
    final builtInMethods = [
      {'id': 'cash', 'label': 'Cash', 'icon': Icons.payments_outlined},
      {'id': 'bank_transfer', 'label': 'Bank', 'icon': Icons.account_balance_outlined},
      {'id': 'card', 'label': 'Card', 'icon': Icons.credit_card_outlined},
      {'id': 'other', 'label': 'Other', 'icon': Icons.receipt_outlined},
    ];
    
    if (instructor != null) {
      final customMethods = instructor.instructorSettings?.customPaymentMethods ?? [];
      final customMethodList = customMethods.map((m) => {
        'id': m.id,
        'label': m.label,
        'icon': Icons.payments_outlined,
      }).toList();
      
      return [...builtInMethods, ...customMethodList];
    }
    
    return builtInMethods;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.success;
      case 'inactive':
        return AppTheme.neutral500;
      case 'passed':
        return AppTheme.info;
      default:
        return AppTheme.neutral500;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.successLight;
      case 'inactive':
        return AppTheme.neutral200;
      case 'passed':
        return AppTheme.infoLight;
      default:
        return AppTheme.neutral200;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to make call: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final uri = Uri.parse('sms:$phoneNumber');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to send message: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
