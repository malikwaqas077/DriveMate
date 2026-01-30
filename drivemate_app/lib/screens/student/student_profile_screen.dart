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
import 'student_profile_edit_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  StudentProfileScreen({super.key, required this.profile});

  final UserProfile profile;
  final FirestoreService _firestoreService = FirestoreService();

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final studentId = profile.studentId;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          if (studentId == null) ...[
            _buildCompactProfileHeader(context, null),
            const SizedBox(height: 20),
            _buildNotLinkedCard(context),
          ] else
            StreamBuilder<Student?>(
              stream: _firestoreService.streamStudentById(studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading profile...');
                }
                final student = snapshot.data;
                if (student == null) {
                  return Column(
                    children: [
                      _buildCompactProfileHeader(context, null),
                      const SizedBox(height: 20),
                      _buildNotLinkedCard(context),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildCompactProfileHeader(context, student),
                    const SizedBox(height: 16),
                    _buildBalanceCard(context, student),
                    const SizedBox(height: 16),
                    _buildHoursAndPayments(context, studentId, student),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompactProfileHeader(BuildContext context, Student? student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(profile.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Student',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (student != null)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentProfileEditScreen(
                      profile: profile,
                      student: student,
                    ),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotLinkedCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.link_off_rounded,
              color: AppTheme.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile Not Linked',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is not linked to a student record yet. Contact your instructor to get linked.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = student.balanceHours < 0
        ? AppTheme.error
        : student.balanceHours > 0
            ? AppTheme.success
            : colorScheme.onSurfaceVariant;
    final balanceBgColor = student.balanceHours < 0
        ? AppTheme.errorLight
        : student.balanceHours > 0
            ? AppTheme.successLight
            : colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.all(20),
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
                  'Credit Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      student.balanceHours.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: balanceColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'hours',
                        style: TextStyle(
                          fontSize: 14,
                          color: balanceColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: balanceBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              student.balanceHours < 0
                  ? Icons.warning_amber_rounded
                  : Icons.schedule_rounded,
              color: balanceColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursAndPayments(BuildContext context, String studentId, Student student) {
    return StreamBuilder<List<Payment>>(
      stream: _firestoreService.streamPaymentsForStudent(studentId),
      builder: (context, paymentSnapshot) {
        if (paymentSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading payments...');
        }
        final payments = paymentSnapshot.data ?? [];
        final totalPaidHours = payments.fold<double>(
          0,
          (total, payment) => total + payment.hoursPurchased,
        );
        final totalPaidAmount = payments.fold<double>(
          0,
          (total, payment) => total + payment.amount,
        );
        return StreamBuilder<List<Lesson>>(
          stream: _firestoreService.streamLessonsForStudent(studentId),
          builder: (context, lessonSnapshot) {
            if (lessonSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading lessons...');
            }
            final lessons = lessonSnapshot.data ?? [];
            final now = DateTime.now();
            final completedHours = lessons
                .where((lesson) => !lesson.startAt.isAfter(now))
                .fold<double>(0, (total, lesson) => total + lesson.durationHours);
            final bookedHours = lessons
                .where((lesson) => lesson.startAt.isAfter(now))
                .fold<double>(0, (total, lesson) => total + lesson.durationHours);
            final remainingHours = totalPaidHours - completedHours - bookedHours;

            return Column(
              children: [
                _buildStatisticsCard(
                  context,
                  totalLessons: lessons.length,
                  completedLessons: lessons.where((l) => !l.startAt.isAfter(now)).length,
                  totalSpent: totalPaidAmount,
                  hourlyRate: student.hourlyRate,
                ),
                const SizedBox(height: 16),
                _buildHoursSummaryCard(
                  context,
                  totalPaidHours: totalPaidHours,
                  completedHours: completedHours,
                  bookedHours: bookedHours,
                  remainingHours: remainingHours,
                ),
                const SizedBox(height: 16),
                _buildPaymentsHistory(context, payments),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsCard(
    BuildContext context, {
    required int totalLessons,
    required int completedLessons,
    required double totalSpent,
    required double? hourlyRate,
  }) {
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
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.event_available_rounded,
                  iconColor: AppTheme.success,
                  iconBgColor: AppTheme.successLight,
                  label: 'Completed',
                  value: '$completedLessons',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppTheme.info,
                  iconBgColor: AppTheme.infoLight,
                  label: 'Total Lessons',
                  value: '$totalLessons',
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
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                  label: 'Total Spent',
                  value: '£${totalSpent.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.speed_rounded,
                  iconColor: AppTheme.secondary,
                  iconBgColor: AppTheme.secondaryLight,
                  label: 'Hourly Rate',
                  value: hourlyRate != null ? '£${hourlyRate.toStringAsFixed(0)}' : 'N/A',
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
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
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
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursSummaryCard(
    BuildContext context, {
    required double totalPaidHours,
    required double completedHours,
    required double bookedHours,
    required double remainingHours,
  }) {
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppTheme.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Hours Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHoursRow(
            context,
            'Total hours purchased',
            totalPaidHours,
            colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          _buildHoursRow(
            context,
            'Hours completed',
            completedHours,
            AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 12),
          _buildHoursRow(
            context,
            'Upcoming lessons',
            bookedHours,
            AppTheme.info,
            icon: Icons.event_outlined,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: colorScheme.outlineVariant),
          ),
          _buildHoursRow(
            context,
            'Available credit',
            remainingHours,
            remainingHours < 0 ? AppTheme.error : AppTheme.primary,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHoursRow(
    BuildContext context,
    String label,
    double value,
    Color valueColor, {
    IconData? icon,
    bool isBold = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: valueColor),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)}h',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsHistory(BuildContext context, List<Payment> payments) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: InlineEmptyView(
                message: 'No payments recorded yet',
                icon: Icons.receipt_long_outlined,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _buildPaymentItem(context, payment);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(BuildContext context, Payment payment) {
    final methodIcon = switch (payment.method) {
      'cash' => Icons.payments_outlined,
      'bank_transfer' => Icons.account_balance_outlined,
      'card' => Icons.credit_card_outlined,
      _ => Icons.receipt_outlined,
    };
    final colorScheme = Theme.of(context).colorScheme;
    final methodColor = switch (payment.method) {
      'cash' => AppTheme.success,
      'bank_transfer' => AppTheme.info,
      'card' => const Color(0xFF8B5CF6),
      _ => colorScheme.onSurfaceVariant,
    };
    final methodBgColor = switch (payment.method) {
      'cash' => AppTheme.successLight,
      'bank_transfer' => AppTheme.infoLight,
      'card' => const Color(0xFFEDE9FE),
      _ => colorScheme.surfaceContainerHighest,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: methodBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(methodIcon, color: methodColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.hoursPurchased.toStringAsFixed(1)} hours purchased',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy').format(payment.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '£${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}
