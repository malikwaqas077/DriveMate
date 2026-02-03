import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/lesson.dart';
import '../../models/school_instructor.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_view.dart';
import '../instructor/student_detail_screen.dart';

/// Owner view of a single instructor: students, schedule, reports summary.
class OwnerInstructorDetailScreen extends StatelessWidget {
  const OwnerInstructorDetailScreen({
    super.key,
    required this.owner,
    required this.link,
    required this.instructorName,
    required this.accessStatus,
  });

  final UserProfile owner;
  final SchoolInstructor link;
  final String instructorName;
  final String accessStatus;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          instructorName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Student>>(
        stream: firestoreService.streamStudents(link.instructorId),
        builder: (context, studentsSnapshot) {
          if (studentsSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading...');
          }
          final students = studentsSnapshot.data ?? [];
          return StreamBuilder<List<Lesson>>(
            stream: firestoreService.streamLessonsForInstructor(link.instructorId),
            builder: (context, lessonsSnapshot) {
              if (lessonsSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading schedule...');
              }
              final lessons = lessonsSnapshot.data ?? [];
              final upcomingLessons = lessons
                  .where((l) =>
                      l.status != 'cancelled' &&
                      !l.startAt.isBefore(now))
                  .toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt));
              final weekLessons = lessons
                  .where((l) =>
                      !l.startAt.isBefore(weekStart) &&
                      l.startAt.isBefore(weekEnd))
                  .toList();
              final monthLessons = lessons
                  .where((l) =>
                      !l.startAt.isBefore(monthStart) &&
                      l.startAt.isBefore(monthEnd))
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    link: link,
                    accessStatus: accessStatus,
                    studentCount: students.length,
                    weekLessons: weekLessons,
                    monthLessons: monthLessons,
                    weekStart: weekStart,
                    weekEnd: weekEnd,
                    now: now,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Upcoming lessons'),
                  if (upcomingLessons.isEmpty)
                    _emptyCard(context, 'No upcoming lessons')
                  else
                    ...upcomingLessons.take(10).map((l) => _LessonTile(
                          lesson: l,
                          firestoreService: firestoreService,
                        )),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Students (${students.length})'),
                  if (students.isEmpty)
                    _emptyCard(context, 'No students yet')
                  else
                    ...students.map((s) => _StudentTile(
                          student: s,
                          instructorId: link.instructorId,
                        )),
                ],
              );
            },
          );
        },
      ),
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

  Widget _emptyCard(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.link,
    required this.accessStatus,
    required this.studentCount,
    required this.weekLessons,
    required this.monthLessons,
    required this.weekStart,
    required this.weekEnd,
    required this.now,
  });

  final SchoolInstructor link;
  final String accessStatus;
  final int studentCount;
  final List<Lesson> weekLessons;
  final List<Lesson> monthLessons;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final weekCompleted =
        weekLessons.where((l) => l.status == 'completed').length;
    final monthCompleted =
        monthLessons.where((l) => l.status == 'completed').length;
    final weekHours =
        weekLessons.fold(0.0, (s, l) => s + l.durationHours);
    final monthHours =
        monthLessons.fold(0.0, (s, l) => s + l.durationHours);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statChip(
                  context,
                  Icons.people_outline,
                  '$studentCount students',
                ),
                const SizedBox(width: 8),
                _statChip(
                  context,
                  Icons.lock_outline,
                  accessStatus,
                  color: accessStatus == 'approved'
                      ? AppTheme.success
                      : accessStatus == 'pending'
                          ? AppTheme.warning
                          : AppTheme.neutral500,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Fee: £${link.feeAmount.toStringAsFixed(2)} / ${link.feeFrequency}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            Text(
              'This week',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '$weekCompleted completed · ${weekHours.toStringAsFixed(1)}h',
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
            const SizedBox(height: 4),
            Text(
              '$monthCompleted completed · ${monthHours.toStringAsFixed(1)}h',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.firestoreService,
  });

  final Lesson lesson;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: firestoreService.getStudentById(lesson.studentId),
      builder: (context, snapshot) {
        final studentName = snapshot.data?.name ?? 'Student';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.schedule, color: AppTheme.primary, size: 20),
            ),
            title: Text(studentName),
            subtitle: Text(
              '${DateFormat('EEE dd MMM').format(lesson.startAt)} · '
              '${DateFormat('HH:mm').format(lesson.startAt)} · '
              '${lesson.durationHours}h',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(lesson.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lesson.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(lesson.status),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'scheduled':
        return AppTheme.info;
      case 'cancelled':
        return AppTheme.warning;
      default:
        return AppTheme.neutral500;
    }
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.instructorId,
  });

  final Student student;
  final String instructorId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: context.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              _getInitials(student.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        title: Text(student.name),
        subtitle: Text(
          '${student.status} · ${student.balanceHours.toStringAsFixed(1)}h balance',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(
                studentId: student.id,
                studentName: student.name,
                instructorId: instructorId,
              ),
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
