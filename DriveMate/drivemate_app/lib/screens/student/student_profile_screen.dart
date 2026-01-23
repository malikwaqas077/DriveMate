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
          // Profile Header Card
          _buildProfileHeader(context),
          const SizedBox(height: 20),
          if (studentId == null)
            _buildNotLinkedCard(context)
          else
            StreamBuilder<Student?>(
              stream: _firestoreService.streamStudentById(studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading profile...');
                }
                final student = snapshot.data;
                if (student == null) {
                  return _buildNotLinkedCard(context);
                }
                return Column(
                  children: [
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

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(profile.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLinkedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
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
          const Text(
            'Profile Not Linked',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is not linked to a student record yet. Contact your instructor to get linked.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neutral600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, Student student) {
    final balanceColor = student.balanceHours < 0
        ? AppTheme.error
        : student.balanceHours > 0
            ? AppTheme.success
            : AppTheme.neutral500;
    final balanceBgColor = student.balanceHours < 0
        ? AppTheme.errorLight
        : student.balanceHours > 0
            ? AppTheme.successLight
            : AppTheme.neutral100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Credit Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutral500,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
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
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFFEDE9FE),
                  label: 'Total Spent',
                  value: '£${totalSpent.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
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

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.neutral500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neutral900,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
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
              const Text(
                'Hours Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHoursRow(
            'Total hours purchased',
            totalPaidHours,
            AppTheme.neutral700,
          ),
          const SizedBox(height: 12),
          _buildHoursRow(
            'Hours completed',
            completedHours,
            AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 12),
          _buildHoursRow(
            'Upcoming lessons',
            bookedHours,
            AppTheme.info,
            icon: Icons.event_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildHoursRow(
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
    String label,
    double value,
    Color valueColor, {
    IconData? icon,
    bool isBold = false,
  }) {
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
              color: isBold ? AppTheme.neutral900 : AppTheme.neutral600,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
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
                const Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral900,
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
                color: AppTheme.neutral200,
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
    final methodColor = switch (payment.method) {
      'cash' => AppTheme.success,
      'bank_transfer' => AppTheme.info,
      'card' => const Color(0xFF8B5CF6),
      _ => AppTheme.neutral500,
    };
    final methodBgColor = switch (payment.method) {
      'cash' => AppTheme.successLight,
      'bank_transfer' => AppTheme.infoLight,
      'card' => const Color(0xFFEDE9FE),
      _ => AppTheme.neutral100,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy').format(payment.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutral500,
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
