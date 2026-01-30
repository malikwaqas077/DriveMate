import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cancellation_request.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class StudentLessonsScreen extends StatefulWidget {
  const StudentLessonsScreen({
    super.key,
    required this.studentId,
    this.instructorId,
  });

  final String? studentId;
  final String? instructorId;

  @override
  State<StudentLessonsScreen> createState() => _StudentLessonsScreenState();
}

class _StudentLessonsScreenState extends State<StudentLessonsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  UserProfile? _instructor;
  Map<String, CancellationRequest> _cancellationRequests = {};

  @override
  void initState() {
    super.initState();
    _loadInstructorSettings();
    _loadCancellationRequests();
  }

  Future<void> _loadInstructorSettings() async {
    if (widget.instructorId == null) return;
    final profile = await _firestoreService.getUserProfile(widget.instructorId!);
    if (mounted && profile != null) {
      setState(() => _instructor = profile);
    }
  }

  void _loadCancellationRequests() {
    if (widget.studentId == null) return;
    _firestoreService.streamCancellationRequestsForStudent(widget.studentId!)
        .listen((requests) {
      if (mounted) {
        setState(() {
          _cancellationRequests = {
            for (final r in requests) r.lessonId: r,
          };
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.studentId == null) {
      return const EmptyView(
        message: 'No linked student profile yet',
        subtitle: 'Contact your instructor to link your account',
        type: EmptyViewType.lessons,
      );
    }
    return StreamBuilder<List<Lesson>>(
      stream: _firestoreService.streamLessonsForStudent(widget.studentId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading lessons...');
        }
        final allLessons = snapshot.data ?? [];
        // Filter out cancelled lessons for display
        final lessons = allLessons
            .where((lesson) => lesson.status != 'cancelled')
            .toList();
        if (lessons.isEmpty) {
          return const EmptyView(
            message: 'No lessons yet',
            subtitle: 'Your lessons will appear here once scheduled',
            type: EmptyViewType.lessons,
          );
        }
        final now = DateTime.now();
        final upcoming = lessons
            .where((lesson) => lesson.startAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final past = lessons
            .where((lesson) => !lesson.startAt.isAfter(now))
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        final lastPastLesson = past.isNotEmpty ? past.first : null;
        final nextLesson = upcoming.isNotEmpty ? upcoming.first : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Next Lesson Hero Card
              if (nextLesson != null) _buildNextLessonCard(context, nextLesson),
              if (nextLesson != null) const SizedBox(height: 24),

              // Last Lesson Reflection
              if (lastPastLesson != null) ...[
                _buildSectionHeader(context, 'Last Lesson Reflection'),
                const SizedBox(height: 12),
                _buildReflectionCard(context, lastPastLesson),
                const SizedBox(height: 24),
              ],

              // Upcoming Lessons
              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader(context, 'Upcoming Lessons'),
                const SizedBox(height: 12),
                _buildLessonList(context, upcoming.skip(nextLesson != null ? 1 : 0).toList(), false),
                const SizedBox(height: 24),
              ],

              // Past Lessons
              if (past.isNotEmpty) ...[
                _buildSectionHeader(context, 'Past Lessons'),
                const SizedBox(height: 12),
                _buildLessonList(context, past.skip(lastPastLesson != null ? 1 : 0).toList(), true),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildNextLessonCard(BuildContext context, Lesson lesson) {
    final timeRange = _formatLessonTimeRange(lesson);
    final daysUntil = lesson.startAt.difference(DateTime.now()).inDays;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEEE, d MMMM').format(lesson.startAt);
    }

    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isToday ? 'TODAY' : isTomorrow ? 'TOMORROW' : 'UPCOMING',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildLessonTypeTag(lesson.lessonType),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Next Lesson',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: timeRange,
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildInfoItem(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Duration',
                        value: '${lesson.durationHours.toStringAsFixed(1)}h',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationButton(BuildContext context, Lesson lesson) {
    final existingRequest = _cancellationRequests[lesson.id];
    
    // If there's already a pending request
    if (existingRequest != null && existingRequest.status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Cancellation Pending',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCancellationDialog(context, lesson),
        icon: const Icon(Icons.event_busy_rounded, size: 18),
        label: const Text('Request Cancellation'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTypeTag(String lessonType) {
    final color = switch (lessonType) {
      'mock_test' => const Color(0xFF8B5CF6),
      'test' => AppTheme.info,
      _ => Colors.white,
    };
    final label = switch (lessonType) {
      'mock_test' => 'Mock Test',
      'test' => 'Driving Test',
      _ => 'Lesson',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(lessonType == 'lesson' ? 0.2 : 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: lessonType == 'lesson' ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReflectionCard(BuildContext context, Lesson lesson) {
    final colorScheme = Theme.of(context).colorScheme;
    final reflection = lesson.studentReflection?.trim();
    final timeRange = _formatLessonTimeRange(lesson);
    final hasReflection = reflection != null && reflection.isNotEmpty;

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasReflection ? Icons.edit_note_rounded : Icons.note_add_rounded,
                  color: AppTheme.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(lesson.startAt),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildLessonTypeBadge(lesson.lessonType),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasReflection ? reflection : 'No reflection added yet. Tap to add your thoughts about this lesson.',
              style: TextStyle(
                fontSize: 14,
                color: hasReflection ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontStyle: hasReflection ? FontStyle.normal : FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showReflectionEditor(context, lesson),
              icon: Icon(hasReflection ? Icons.edit_rounded : Icons.add_rounded, size: 18),
              label: Text(hasReflection ? 'Edit Reflection' : 'Add Reflection'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary.withOpacity(0.15),
                foregroundColor: colorScheme.primary,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTypeBadge(String lessonType) {
    // Use darker text on light backgrounds for clear contrast (especially orange "Lesson" tag)
    final textColor = switch (lessonType) {
      'mock_test' => const Color(0xFF5B21B6), // dark purple on light purple
      'test' => const Color(0xFF1D4ED8), // dark blue on infoLight
      _ => AppTheme.secondaryDark, // dark orange on secondaryLight so "Lesson" is readable
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

  Widget _buildLessonList(BuildContext context, List<Lesson> lessons, bool showReflection) {
    final colorScheme = Theme.of(context).colorScheme;
    if (lessons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            showReflection ? 'No more past lessons' : 'No more upcoming lessons',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lessons.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          return _buildLessonListItem(context, lesson, showReflection);
        },
      ),
    );
  }

  Widget _buildLessonListItem(BuildContext context, Lesson lesson, bool showReflection) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeRange = _formatLessonTimeRange(lesson);
    final reflection = lesson.studentReflection?.trim();
    final hasReflection = reflection != null && reflection.isNotEmpty;
    final existingRequest = _cancellationRequests[lesson.id];
    final hasPendingCancellation = existingRequest?.status == 'pending';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showReflection ? () => _showReflectionEditor(context, lesson) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: showReflection ? colorScheme.surfaceContainerHighest : colorScheme.primary.withOpacity(0.15),
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
                        color: showReflection ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(lesson.startAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: showReflection ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Info
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
                    if (showReflection) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            hasReflection ? Icons.check_circle_outline : Icons.edit_note_outlined,
                            size: 14,
                            color: hasReflection ? AppTheme.success : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasReflection ? 'Reflection added' : 'Tap to add reflection',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasReflection ? AppTheme.success : colorScheme.onSurfaceVariant,
                                fontStyle: hasReflection ? FontStyle.normal : FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show cancellation status for upcoming lessons
                    if (!showReflection && hasPendingCancellation) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.hourglass_empty_rounded,
                            size: 14,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Cancellation pending',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showReflection)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              if (!showReflection)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 0),
                  onSelected: (value) {
                    if (value == 'request_cancellation') {
                      _showCancellationDialog(context, lesson);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'request_cancellation',
                      child: Row(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Request cancellation'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReflectionEditor(BuildContext context, Lesson lesson) async {
    final controller = TextEditingController(text: lesson.studentReflection ?? '');
    bool saving = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: AppTheme.warning),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lesson Reflection',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                DateFormat('d MMMM yyyy').format(lesson.startAt),
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Form
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What did you learn in this lesson?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Record your thoughts, progress, and areas to improve.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'E.g., Practiced roundabouts today. Need to work on checking mirrors more frequently...',
                                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
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
                                    setDialogState(() => saving = true);
                                    await _firestoreService.updateLessonReflection(
                                      lessonId: lesson.id,
                                      reflection: controller.text,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                            child: saving
                                ? LoadingIndicator(size: 20, color: colorScheme.onPrimary)
                                : const Text('Save Reflection'),
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

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Reflection saved'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _showCancellationDialog(BuildContext context, Lesson lesson) async {
    // Calculate charge percentage based on instructor's cancellation rules
    int effectiveCharge = 0;
    int? matchingRuleHours = null;
    if (_instructor != null) {
      final rules = _instructor!.getCancellationRules();
      final hoursUntilLesson = lesson.startAt.difference(DateTime.now()).inHours;
      
      // Find the first matching rule (rules should be sorted by hoursBefore descending)
      // A rule matches if hoursUntilLesson <= rule.hoursBefore
      for (final rule in rules) {
        if (hoursUntilLesson <= rule.hoursBefore) {
          effectiveCharge = rule.chargePercent;
          matchingRuleHours = rule.hoursBefore;
          break;
        }
      }
      // If no rule matches, charge is 0 (free cancellation)
    }

    final isWithinWindow = effectiveCharge > 0;
    final reasonController = TextEditingController();
    bool submitting = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 360;
            final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
            final buttonSpacing = isSmallScreen ? 8.0 : 12.0;
            
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      isSmallScreen ? 8.0 : 16.0,
                      16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isSmallScreen ? 40.0 : 44,
                          height: isSmallScreen ? 40.0 : 44,
                          decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event_busy_rounded, color: AppTheme.warning),
                        ),
                        SizedBox(width: isSmallScreen ? 12.0 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Cancellation',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16.0 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, d MMMM').format(lesson.startAt),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12.0 : 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Charge info
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16),
                          decoration: BoxDecoration(
                            color: isWithinWindow
                                ? AppTheme.warningLight
                                : AppTheme.successLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isWithinWindow
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                size: isSmallScreen ? 20.0 : 24,
                                color: isWithinWindow
                                    ? AppTheme.warning
                                    : AppTheme.success,
                              ),
                              SizedBox(width: isSmallScreen ? 10.0 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isWithinWindow
                                          ? 'Late Cancellation'
                                          : 'Free Cancellation',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13.0 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: isWithinWindow
                                            ? AppTheme.warning
                                            : AppTheme.success,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isWithinWindow
                                          ? '$effectiveCharge% of lesson hours (${(lesson.durationHours * effectiveCharge / 100).toStringAsFixed(1)}h) will be charged'
                                          : matchingRuleHours != null
                                              ? 'No charges apply - lesson is more than $matchingRuleHours hours away'
                                              : 'No charges apply for this cancellation',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12.0 : 13,
                                        color: isWithinWindow
                                            ? AppTheme.warning
                                            : AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16.0 : 20),
                        // Reason input
                        Text(
                          'Reason (optional)',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13.0 : 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Let your instructor know why you need to cancel...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: isSmallScreen ? 14.0 : 16,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Footer
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      isSmallScreen ? 20.0 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: isSmallScreen
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: submitting
                                      ? null
                                      : () async {
                                          setDialogState(() => submitting = true);
                                          try {
                                            final request = CancellationRequest(
                                              id: '',
                                              lessonId: lesson.id,
                                              studentId: lesson.studentId,
                                              instructorId: lesson.instructorId,
                                              schoolId: lesson.schoolId,
                                              status: 'pending',
                                              reason: reasonController.text.trim().isEmpty
                                                  ? null
                                                  : reasonController.text.trim(),
                                              chargePercent: effectiveCharge,
                                              hoursToDeduct: lesson.durationHours,
                                              createdAt: DateTime.now(),
                                              lessonStartAt: lesson.startAt,
                                            );
                                            await _firestoreService.createCancellationRequest(request);
                                            if (context.mounted) {
                                              Navigator.pop(context, true);
                                            }
                                          } catch (e) {
                                            setDialogState(() => submitting = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: AppTheme.error,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.warning,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    alignment: Alignment.center,
                                  ),
                                  child: submitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                                          ),
                                        )
                                      : const Center(child: Text('Request Cancellation')),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: submitting ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Keep Lesson'),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: submitting ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Keep Lesson'),
                                ),
                              ),
                              SizedBox(width: buttonSpacing),
                              Expanded(
                                child: FilledButton(
                                  onPressed: submitting
                                      ? null
                                      : () async {
                                          setDialogState(() => submitting = true);
                                          try {
                                            final request = CancellationRequest(
                                              id: '',
                                              lessonId: lesson.id,
                                              studentId: lesson.studentId,
                                              instructorId: lesson.instructorId,
                                              schoolId: lesson.schoolId,
                                              status: 'pending',
                                              reason: reasonController.text.trim().isEmpty
                                                  ? null
                                                  : reasonController.text.trim(),
                                              chargePercent: effectiveCharge,
                                              hoursToDeduct: lesson.durationHours,
                                              createdAt: DateTime.now(),
                                              lessonStartAt: lesson.startAt,
                                            );
                                            await _firestoreService.createCancellationRequest(request);
                                            if (context.mounted) {
                                              Navigator.pop(context, true);
                                            }
                                          } catch (e) {
                                            setDialogState(() => submitting = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: AppTheme.error,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.warning,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    alignment: Alignment.center,
                                  ),
                                  child: submitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                                          ),
                                        )
                                      : const Center(child: Text('Request Cancellation')),
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

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Cancellation request sent'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatLessonTimeRange(Lesson lesson) {
    final start = lesson.startAt;
    final minutes = (lesson.durationHours * 60).round();
    final end = start.add(Duration(minutes: minutes));
    final formatter = DateFormat('HH:mm');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }
}
