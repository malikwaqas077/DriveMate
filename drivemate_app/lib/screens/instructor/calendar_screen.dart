import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import 'student_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  static const int _defaultStartHour = 6; // Default start hour (06:00)
  static const int _endHour = 24;
  static const int _defaultScrollHour = 6; // Default scroll to 06:00
  static const double _hourHeight = 70;
  static const double _timeColumnWidth = 40;
  static const double _compactBreakpoint = 380;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _didAutoScroll = false;
  late final ScrollController _verticalController;
  late final ScrollController _headerScrollController;
  late final ScrollController _gridScrollController;
  bool _syncingScroll = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _verticalController = ScrollController();
    _headerScrollController = ScrollController();
    _gridScrollController = ScrollController();
    _headerScrollController.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(_headerScrollController.offset);
      }
      _syncingScroll = false;
    });
    _gridScrollController.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_gridScrollController.offset);
      }
      _syncingScroll = false;
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.streamUserProfile(widget.instructor.id),
      builder: (context, instructorSnapshot) {
        final instructor = instructorSnapshot.data ?? widget.instructor;
        
        return StreamBuilder<List<Student>>(
          stream: _firestoreService.streamStudents(instructor.id),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading calendar...');
            }
            final students = studentsSnapshot.data ?? [];
            final studentMap = {
              for (final student in students) student.id: student.name,
            };
            return StreamBuilder<List<Lesson>>(
              stream:
                  _firestoreService.streamLessonsForInstructor(instructor.id),
              builder: (context, lessonSnapshot) {
                if (lessonSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading lessons...');
                }
                final lessons = lessonSnapshot.data ?? [];
                return StreamBuilder<List<Payment>>(
                  stream: _firestoreService
                      .streamPaymentsForInstructor(instructor.id),
                  builder: (context, paymentsSnapshot) {
                    if (paymentsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView(message: 'Loading payments...');
                    }
                    final payments = paymentsSnapshot.data ?? [];
                    final lessonStatuses =
                        _computeLessonStatuses(lessons, payments);
                final selectedDay = _selectedDay ?? DateTime.now();
                final weekDays = _buildWeekDays(_focusedDay);
                // Get default view from settings
                final defaultView = instructor.instructorSettings?.defaultCalendarView ?? 'grid';
                final showList = defaultView == 'list';
                return Scaffold(
                  body: Column(
                    children: [
                      _buildWeekHeader(context, weekDays, selectedDay),
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            // Swipe right (positive velocity) = previous week
                            // Swipe left (negative velocity) = next week
                            const swipeThreshold = 100.0;
                            if (details.primaryVelocity != null) {
                              if (details.primaryVelocity! > swipeThreshold) {
                                // Swipe right - go to previous week
                                setState(() {
                                  _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                                  _selectedDay = _focusedDay;
                                  _didAutoScroll = false;
                                });
                              } else if (details.primaryVelocity! < -swipeThreshold) {
                                // Swipe left - go to next week
                                setState(() {
                                  _focusedDay = _focusedDay.add(const Duration(days: 7));
                                  _selectedDay = _focusedDay;
                                  _didAutoScroll = false;
                                });
                              }
                            }
                          },
                          child: showList
                              ? _buildLessonList(
                                  lessons,
                                  weekDays,
                                  students,
                                  studentMap,
                                  lessonStatuses,
                                )
                              : _buildWeekGrid(
                                  context,
                                  weekDays,
                                  lessons,
                                  students,
                                  studentMap,
                                  selectedDay,
                                  lessonStatuses,
                                  instructor: instructor,
                                ),
                        ),
                      ),
                        ],
                      ),
                      floatingActionButton: FloatingActionButton(
                        onPressed: students.isEmpty
                            ? null
                            : () => _showAddLesson(
                                  context,
                                  students,
                                  selectedDay,
                                ),
                        child: const Icon(Icons.add),
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

  Widget _buildWeekHeader(
    BuildContext context,
    List<DateTime> weekDays,
    DateTime selectedDay,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _timeColumnWidth;
        final isCompact = constraints.maxWidth < _compactBreakpoint;
        final gridWidth = availableWidth;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 4, 8),
          child: Row(
            children: [
              const SizedBox(width: _timeColumnWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: Row(
                      children: weekDays.map((day) {
                        final isSelected = _isSameDay(day, selectedDay);
                        final weekdayLabel = DateFormat('EEE').format(day);
                        final compactWeekday = weekdayLabel.substring(0, 1);
                        return SizedBox(
                          width: gridWidth / weekDays.length,
                          child: InkWell(
                            onTap: () => setState(() => _selectedDay = day),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompact ? 6 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.12)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isCompact ? compactWeekday : weekdayLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontSize: isCompact ? 12 : null,
                                        ),
                                  ),
                                  SizedBox(height: isCompact ? 0 : 2),
                                  Text(
                                    isCompact
                                        ? DateFormat('d').format(day)
                                        : DateFormat('d MMM').format(day),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  int _calculateStartHour(List<Lesson> lessons, List<DateTime> weekDays) {
    // Get lessons in the current week
    final weekLessons = lessons
        .where((lesson) => weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList();
    
    if (weekLessons.isEmpty) {
      // No lessons, use default start hour
      return _defaultStartHour;
    }
    
    // Find the earliest lesson hour
    weekLessons.sort((a, b) => a.startAt.compareTo(b.startAt));
    final earliestLesson = weekLessons.first;
    final earliestHour = earliestLesson.startAt.hour;
    
    // Use the earliest lesson hour, but ensure it's not negative
    // Also ensure we don't go below 0 (midnight)
    final calculatedHour = earliestHour < _defaultStartHour ? earliestHour : _defaultStartHour;
    return calculatedHour.clamp(0, _endHour - 1);
  }

  Widget _buildWeekGrid(
    BuildContext context,
    List<DateTime> weekDays,
    List<Lesson> lessons,
    List<Student> students,
    Map<String, String> studentMap,
    DateTime selectedDay,
    Map<String, _LessonStatus> lessonStatuses, {
    UserProfile? instructor,
  }) {
    final currentInstructor = instructor ?? widget.instructor;
    final startHour = _calculateStartHour(lessons, weekDays);
    // Ensure we always have at least some hours to display
    final totalHours = (_endHour - startHour).clamp(1, _endHour);
    final totalHeight = totalHours * _hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _timeColumnWidth;
        final isCompact = constraints.maxWidth < _compactBreakpoint;
        final gridWidth = availableWidth;
        final dayWidth = gridWidth / weekDays.length;
        return SingleChildScrollView(
          controller: _verticalController,
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeColumn(totalHours, startHour),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _gridScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      height: totalHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildGridBackground(
                            context,
                            weekDays,
                            totalHours,
                            selectedDay,
                          ),
                          _NowIndicator(
                            weekDays: weekDays,
                            dayWidth: dayWidth,
                            startHour: startHour,
                            endHour: _endHour,
                            hourHeight: _hourHeight,
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (details) {
                                if (students.isEmpty) {
                                  _showSnack(
                                    context,
                                    'Add a student first before adding a lesson.',
                                  );
                                  return;
                                }
                                final position = details.localPosition;
                                if (position.dx < 0 || position.dy < 0) return;
                                final dayIndex =
                                    (position.dx / dayWidth).floor().clamp(
                                          0,
                                          weekDays.length - 1,
                                        );
                                final minutesFromStart =
                                    (position.dy / _hourHeight * 60).round();
                                final snappedMinutes =
                                    (minutesFromStart / 15).round() * 15;
                                final totalMinutes = (startHour * 60) +
                                    snappedMinutes.clamp(
                                      0,
                                      (_endHour - startHour) * 60 - 1,
                                    );
                                final tapDate = weekDays[dayIndex as int];
                                final initialStart = DateTime(
                                  tapDate.year,
                                  tapDate.month,
                                  tapDate.day,
                                  totalMinutes ~/ 60,
                                  totalMinutes % 60,
                                );
                                _showAddLesson(
                                  context,
                                  students,
                                  selectedDay,
                                  initialStart: initialStart,
                                );
                              },
                            ),
                          ),
                          ..._buildLessonBlocks(
                            context,
                            lessons,
                            weekDays,
                            dayWidth,
                            students,
                            studentMap,
                            lessonStatuses,
                            startHour,
                            instructor: currentInstructor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonList(
    List<Lesson> lessons,
    List<DateTime> weekDays,
    List<Student> students,
    Map<String, String> studentMap,
    Map<String, _LessonStatus> lessonStatuses,
  ) {
    final weekLessons = lessons
        .where((lesson) => weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (weekLessons.isEmpty) {
      return const EmptyView(message: 'No lessons this week.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: weekLessons.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lesson = weekLessons[index];
        final status = lessonStatuses[lesson.id];
        final unpaidHours = status?.unpaidHours ?? 0;
        final paymentState = _resolvePaymentState(status);
        final statusLabel = _paymentStatusLabel(paymentState, unpaidHours);
        final studentName = studentMap[lesson.studentId] ?? 'Student';
        final student = students.firstWhere(
          (s) => s.id == lesson.studentId,
          orElse: () => Student(
            id: lesson.studentId,
            instructorId: widget.instructor.id,
            name: studentName,
            balanceHours: 0,
            status: 'active',
          ),
        );
        return GestureDetector(
          onTap: () => _showLessonActions(
            context,
            lesson,
            students,
            studentMap,
          ),
          onLongPress: () => _showLessonEditDeleteActions(
            context,
            lesson,
            students,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(studentName),
            subtitle: Text(
              '${DateFormat('EEE, d MMM').format(lesson.startAt)} · '
              '${DateFormat('HH:mm').format(lesson.startAt)} · '
              '$statusLabel',
            ),
            trailing: paymentState == _LessonPaymentState.unpaid
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Unpaid',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildTimeColumn(int totalHours, int startHour) {
    final columnHeight = totalHours * _hourHeight;
    return SizedBox(
      width: _timeColumnWidth,
      height: columnHeight,
      child: Column(
        children: List.generate(
          totalHours,
          (index) {
            final hour = startHour + index;
            return SizedBox(
              height: _hourHeight,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridBackground(
    BuildContext context,
    List<DateTime> weekDays,
    int totalHours,
    DateTime selectedDay,
  ) {
    final dividerColor = Theme.of(context).dividerColor;
    return Positioned.fill(
      child: Row(
        children: weekDays.map((day) {
          final isSelected = _isSameDay(day, selectedDay);
          return Expanded(
            child: Column(
              children: List.generate(
                totalHours,
                (index) => Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.05)
                        : null,
                    border: Border(
                      right: BorderSide(color: dividerColor),
                      bottom: BorderSide(color: dividerColor),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildLessonBlocks(
    BuildContext context,
    List<Lesson> lessons,
    List<DateTime> weekDays,
    double dayWidth,
    List<Student> students,
    Map<String, String> studentMap,
    Map<String, _LessonStatus> lessonStatuses,
    int startHour, {
    UserProfile? instructor,
  }) {
    final currentInstructor = instructor ?? widget.instructor;
    _maybeAutoScrollToLessons(lessons, weekDays, startHour);
    
    // Debug: Log week days and lessons
    debugPrint('[calendar] Building lesson blocks for week: ${weekDays.map((d) => '${d.year}-${d.month}-${d.day}').join(', ')}');
    debugPrint('[calendar] Total lessons: ${lessons.length}, startHour: $startHour');
    
    final filteredLessons = lessons
        .where((lesson) =>
            weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList();
    
    debugPrint('[calendar] Filtered lessons for week: ${filteredLessons.length}');
    for (final lesson in filteredLessons) {
      debugPrint('[calendar] Lesson: ${lesson.startAt.toIso8601String()}, student: ${studentMap[lesson.studentId]}');
    }
    
    return filteredLessons.map((lesson) {
      final dayIndex = weekDays.indexWhere(
        (day) => _isSameDay(day, lesson.startAt),
      );
      if (dayIndex < 0) {
        debugPrint('[calendar] Lesson ${lesson.id} dayIndex < 0');
        return const SizedBox.shrink();
      }
      // Normalize lesson start time to local date for accurate calculation
      final lessonLocal = DateTime(
        lesson.startAt.year,
        lesson.startAt.month,
        lesson.startAt.day,
        lesson.startAt.hour,
        lesson.startAt.minute,
      );
      final startMinutes =
          (lessonLocal.hour * 60 + lessonLocal.minute) -
              (startHour * 60);
      final top = (startMinutes / 60) * _hourHeight;
      final maxHeight = (_endHour - startHour) * _hourHeight;
      
      // Allow lessons that start slightly before startHour (within reason) to still show
      // This handles edge cases where lessons are at the boundary
      if (top < -_hourHeight || top > maxHeight + _hourHeight) {
        debugPrint(
          '[calendar] lesson out of range id=${lesson.id} '
          'start=${lesson.startAt.toIso8601String()} '
          'hour=${lesson.startAt.hour}:${lesson.startAt.minute.toString().padLeft(2, '0')} '
          'top=$top maxHeight=$maxHeight '
          'range=${startHour.toString().padLeft(2, '0')}:00-'
          '${_endHour.toString().padLeft(2, '0')}:00',
        );
        return const SizedBox.shrink();
      }
      
      // Clamp the top position to ensure it's visible
      final clampedTop = top.clamp(0.0, maxHeight);
      
      debugPrint(
        '[calendar] Rendering lesson ${lesson.id} at top=$clampedTop, '
        'dayIndex=$dayIndex, hour=${lesson.startAt.hour}:${lesson.startAt.minute.toString().padLeft(2, '0')}',
      );
      final height = lesson.durationHours * _hourHeight;
      final left = dayIndex * dayWidth + 4;
      final status = lessonStatuses[lesson.id];
      final unpaidHours = status?.unpaidHours ?? 0;
      final paymentState = _resolvePaymentState(status);
      final isPast = _isLessonPast(lesson);
      final backgroundColor = _lessonColor(
        lessonType: lesson.lessonType,
        isPast: isPast,
        instructor: currentInstructor,
      );
      final statusLabel = _paymentStatusLabel(paymentState, unpaidHours);
      final endAt = lesson.startAt.add(
        Duration(minutes: (lesson.durationHours * 60).round()),
      );
      final statusBarColor = paymentState == _LessonPaymentState.unpaid
          ? Colors.red.shade600
          : paymentState == _LessonPaymentState.paid
              ? const Color(0xFF4CAF50)
              : Colors.grey;
      return Positioned(
        top: clampedTop,
        left: dayIndex * dayWidth + 1,
        width: dayWidth - 2,
        height: height,
        child: GestureDetector(
          onTap: () => _showLessonActions(
            context,
            lesson,
            students,
            studentMap,
          ),
          onLongPress: () => _showLessonEditDeleteActions(
            context,
            lesson,
            students,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: backgroundColor,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    color: statusBarColor,
                    child: Text(
                      statusLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  top: 3,
                  bottom: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(lesson.startAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(endAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          studentMap[lesson.studentId] ?? 'Student',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<DateTime> _buildWeekDays(DateTime focusedDay) {
    final start = _startOfWeek(focusedDay);
    return List.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    // Normalize both dates to local time and compare only date components
    final aLocal = DateTime(a.year, a.month, a.day);
    final bLocal = DateTime(b.year, b.month, b.day);
    return aLocal == bLocal;
  }

  bool _isLessonPast(Lesson lesson) {
    final endAt = lesson.startAt.add(
      Duration(
        minutes: (lesson.durationHours * 60).round(),
      ),
    );
    return endAt.isBefore(DateTime.now());
  }

  _LessonPaymentState _resolvePaymentState(_LessonStatus? status) {
    if (status == null) return _LessonPaymentState.pending;
    if (status.unpaidHours > 0) return _LessonPaymentState.unpaid;
    return _LessonPaymentState.paid;
  }

  String _paymentStatusLabel(_LessonPaymentState state, double unpaidHours) {
    switch (state) {
      case _LessonPaymentState.unpaid:
        return 'Unpaid';
      case _LessonPaymentState.paid:
        return 'Paid';
      case _LessonPaymentState.pending:
        return 'Pending';
    }
  }

  Color _lessonColor({
    required String lessonType,
    required bool isPast,
    UserProfile? instructor,
  }) {
    // Get custom colors from settings, or use defaults
    final currentInstructor = instructor ?? widget.instructor;
    final settings = currentInstructor.instructorSettings;
    final savedColors = settings?.lessonColors;
    
    Color base;
    if (savedColors != null && savedColors.containsKey(lessonType)) {
      base = Color(savedColors[lessonType]!);
    } else {
      // Check if it's a custom lesson type
      final customTypes = settings?.customLessonTypes ?? [];
      try {
        final customType = customTypes.firstWhere((t) => t.id == lessonType);
        if (customType.color != null) {
          base = Color(customType.color!);
        } else {
          base = switch (lessonType) {
            'test' => Colors.blue,
            'mock_test' => Colors.deepPurple,
            _ => Colors.orange,
          };
        }
      } catch (_) {
        base = switch (lessonType) {
          'test' => Colors.blue,
          'mock_test' => Colors.deepPurple,
          _ => Colors.orange,
        };
      }
    }
    
    return base.withOpacity(isPast ? 0.85 : 0.9);
  }

  String _lessonTypeLabel(String lessonType, {UserProfile? instructor}) {
    switch (lessonType) {
      case 'mock_test':
        return 'Mock test';
      case 'test':
        return 'Driving test';
      case 'lesson':
        return 'Driving lesson';
      default:
        // Check if it's a custom lesson type
        if (instructor != null) {
          final customTypes = instructor.instructorSettings?.customLessonTypes ?? [];
          try {
            final customType = customTypes.firstWhere((t) => t.id == lessonType);
            return customType.label;
          } catch (_) {
            return lessonType; // Fallback to type ID if not found
          }
        }
        return lessonType;
    }
  }

  List<Map<String, dynamic>> _getAllLessonTypes({UserProfile? instructor}) {
    final builtInTypes = [
      {'id': 'lesson', 'label': 'Driving lesson'},
      {'id': 'test', 'label': 'Driving test'},
      {'id': 'mock_test', 'label': 'Mock test'},
    ];
    
    if (instructor != null) {
      final customTypes = instructor.instructorSettings?.customLessonTypes ?? [];
      final customTypeList = customTypes.map((t) => {
        'id': t.id,
        'label': t.label,
      }).toList();
      
      return [...builtInTypes, ...customTypeList];
    }
    
    return builtInTypes;
  }

  List<Map<String, dynamic>> _getLessonTypeOptionsFromList(List<CustomLessonType> customTypes) {
    const builtIn = [
      {'id': 'lesson', 'label': 'Driving lesson'},
      {'id': 'test', 'label': 'Driving test'},
      {'id': 'mock_test', 'label': 'Mock test'},
    ];
    final custom = customTypes.map((t) => {'id': t.id, 'label': t.label}).toList();
    return [...builtIn, ...custom];
  }

  static const String _addNewLessonTypeValue = '__add_new__';

  Widget _buildLessonTypeDropdown(
    BuildContext context,
    String lessonType,
    List<CustomLessonType> customTypes,
    void Function(String) onLessonTypeChanged,
    StateSetter setDialogState,
  ) {
    final options = _getLessonTypeOptionsFromList(customTypes);
    final value = lessonType == _addNewLessonTypeValue || !options.any((o) => o['id'] == lessonType)
        ? 'lesson'
        : lessonType;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(labelText: 'Lesson type'),
      items: [
        ...options.map((type) => DropdownMenuItem(
          value: type['id'] as String,
          child: Text(type['label'] as String),
        )),
        const DropdownMenuItem(
          value: _addNewLessonTypeValue,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 20, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Add new type...', style: TextStyle(color: AppTheme.primary)),
            ],
          ),
        ),
      ],
      onChanged: (value) async {
        if (value == null) return;
        if (value == _addNewLessonTypeValue) {
          final newId = await _showAddLessonTypeDialogResult(context, customTypes, setDialogState);
          if (newId != null) {
            onLessonTypeChanged(newId);
            setDialogState(() {});
          }
          return;
        }
        onLessonTypeChanged(value);
      },
    );
  }

  Future<String?> _showAddLessonTypeDialogResult(
    BuildContext context,
    List<CustomLessonType> customTypes,
    StateSetter setDialogState,
  ) async {
    final labelController = TextEditingController();
    Color selectedColor = Colors.orange;
    final colors = [Colors.orange, Colors.blue, Colors.deepPurple, Colors.green, Colors.red, Colors.teal, Colors.pink, Colors.amber];
    final resultId = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New lesson type'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Type name', hintText: 'e.g. Intensive'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final isSelected = c.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final label = labelController.text.trim();
                if (label.isEmpty) return;
                final id = label.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
                if (id.isEmpty) return;
                if (customTypes.any((t) => t.id == id)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This lesson type already exists')));
                  return;
                }
                customTypes.add(CustomLessonType(id: id, label: label, color: selectedColor.value));
                final current = widget.instructor.instructorSettings;
                final newSettings = InstructorSettings(
                  cancellationRules: current?.cancellationRules,
                  reminderHoursBefore: current?.reminderHoursBefore,
                  notificationSettings: current?.notificationSettings,
                  defaultNavigationApp: current?.defaultNavigationApp,
                  lessonColors: current?.lessonColors,
                  defaultCalendarView: current?.defaultCalendarView,
                  customPaymentMethods: current?.customPaymentMethods,
                  customLessonTypes: customTypes,
                );
                await _firestoreService.updateUserProfile(widget.instructor.id, {'instructorSettings': newSettings.toMap()});
                if (ctx.mounted) Navigator.pop(ctx, id);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    return resultId;
  }


  DateTime _startOfWeek(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final weekday = normalized.weekday;
    return normalized.subtract(Duration(days: weekday - DateTime.monday));
  }

  Widget _buildTag(String text, {Color? backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openStudentProfile(
    BuildContext context,
    String studentId,
    String studentName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(
          studentId: studentId,
          studentName: studentName,
          instructorId: widget.instructor.id,
        ),
      ),
    );
  }

  Future<void> _showLessonActions(
    BuildContext context,
    Lesson lesson,
    List<Student> students,
    Map<String, String> studentMap,
  ) async {
    final studentName = studentMap[lesson.studentId] ?? 'Student';
    final student = students.firstWhere(
      (s) => s.id == lesson.studentId,
      orElse: () => Student(
        id: lesson.studentId,
        instructorId: widget.instructor.id,
        name: studentName,
        balanceHours: 0,
        status: 'active',
      ),
    );
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _openStudentProfile(
                            parentContext,
                            lesson.studentId,
                            studentName,
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 32),
                            const SizedBox(height: 4),
                            const Text('Profile', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    if (student.phone != null && student.phone!.isNotEmpty) ...[
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _makePhoneCall(student.phone!);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone, size: 32, color: AppTheme.primary),
                              const SizedBox(height: 4),
                              const Text('Call', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _sendSMS(student.phone!);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.message, size: 32, color: AppTheme.primary),
                              const SizedBox(height: 4),
                              const Text('Message', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (student.phone != null && student.phone!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    student.phone!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (student.address != null && student.address!.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions_car, color: AppTheme.primary),
                  title: const Text('Drive to student'),
                  subtitle: Text(student.address!),
                  onTap: () {
                    Navigator.pop(context);
                    _openNavigation(student.address!, lesson, student);
                  },
                ),
                const Divider(),
                _buildNotificationButtons(context, lesson, student),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLessonEditDeleteActions(
    BuildContext context,
    Lesson lesson,
    List<Student> students,
  ) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit lesson'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditLesson(parentContext, lesson, students);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete lesson', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _confirmDeleteLesson(parentContext, lesson);
                },
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _openNavigation(String address, Lesson lesson, Student student) async {
    final settings = widget.instructor.instructorSettings;
    final defaultApp = settings?.defaultNavigationApp;
    
    final encodedAddress = Uri.encodeComponent(address);
    Uri url;
    
    if (defaultApp == 'google_maps') {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    } else if (defaultApp == 'apple_maps') {
      url = Uri.parse('https://maps.apple.com/?q=$encodedAddress');
    } else {
      // System default - try Google Maps first, then Apple Maps
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    }
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      
      // Auto-send "on way" notification if enabled
      if (settings?.notificationSettings?['autoSendOnWay'] == true) {
        await _sendNotificationToStudent(lesson, student, 'on_way');
      }
    } catch (e) {
      debugPrint('Error opening navigation: $e');
    }
  }

  Widget _buildNotificationButtons(BuildContext context, Lesson lesson, Student student) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.directions_walk, color: AppTheme.info),
          title: const Text('Notify: On Way'),
          subtitle: const Text('Send notification that you\'re on your way'),
          onTap: () {
            Navigator.pop(context);
            _sendNotificationToStudent(lesson, student, 'on_way');
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on, color: AppTheme.success),
          title: const Text('Notify: Arrived'),
          subtitle: const Text('Send notification that you\'ve arrived'),
          onTap: () {
            Navigator.pop(context);
            _sendNotificationToStudent(lesson, student, 'arrived');
          },
        ),
      ],
    );
  }

  Future<void> _sendNotificationToStudent(Lesson lesson, Student student, String type) async {
    try {
      debugPrint('[Notification] Sending $type notification to student ${student.name} (${student.id})');
      
      // Verify student has a user account linked
      final userProfile = await _firestoreService.getUserProfileByStudentId(student.id);
      if (userProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Student ${student.name} does not have an app account. They need to log in first.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }
      
      if (userProfile.fcmToken == null || userProfile.fcmToken!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Student ${student.name} has not enabled notifications. They need to log in on their device.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }
      
      await _firestoreService.sendInstructorNotification(
        instructorId: widget.instructor.id,
        studentId: student.id,
        lessonId: lesson.id,
        notificationType: type,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Notification sent to ${student.name}'),
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
      debugPrint('[Notification] Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to send notification: $e')),
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _maybeAutoScrollToLessons(
    List<Lesson> lessons,
    List<DateTime> weekDays,
    int startHour,
  ) {
    if (_didAutoScroll || !_verticalController.hasClients) return;
    final weekLessons = lessons
        .where((lesson) => weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList();
    
    // Always scroll to default scroll hour (06:00) relative to the start hour
    final defaultHour =
        _defaultScrollHour.clamp(startHour, _endHour - 1).toInt();
    final defaultMinutesFromStart = (defaultHour - startHour) * 60;
    var targetMinutesFromStart = defaultMinutesFromStart;
    
    // If there are lessons and the earliest one is before the default scroll hour,
    // scroll to show the earliest lesson instead
    if (weekLessons.isNotEmpty) {
      weekLessons.sort((a, b) => a.startAt.compareTo(b.startAt));
      final first = weekLessons.first.startAt;
      final firstMinutesFromStart =
          (first.hour * 60 + first.minute) - (startHour * 60);
      if (firstMinutesFromStart >= 0 && firstMinutesFromStart < defaultMinutesFromStart) {
        targetMinutesFromStart = firstMinutesFromStart;
      }
    }
    
    final top = (targetMinutesFromStart / 60) * _hourHeight;
    _didAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verticalController.hasClients) return;
      final offset = (top - _hourHeight)
          .clamp(0.0, _verticalController.position.maxScrollExtent)
          .toDouble();
      _verticalController.jumpTo(offset);
    });
  }

  Map<String, _LessonStatus> _computeLessonStatuses(
    List<Lesson> lessons,
    List<Payment> payments,
  ) {
    final paidByStudent = <String, double>{};
    for (final payment in payments) {
      paidByStudent[payment.studentId] =
          (paidByStudent[payment.studentId] ?? 0) + payment.hoursPurchased;
    }

    final lessonsByStudent = <String, List<Lesson>>{};
    for (final lesson in lessons) {
      lessonsByStudent.putIfAbsent(lesson.studentId, () => []).add(lesson);
    }

    final result = <String, _LessonStatus>{};
    lessonsByStudent.forEach((studentId, studentLessons) {
      studentLessons.sort((a, b) => a.startAt.compareTo(b.startAt));
      var remaining = paidByStudent[studentId] ?? 0;
      for (final lesson in studentLessons) {
        final unpaidHours = remaining < lesson.durationHours
            ? (lesson.durationHours - remaining).toDouble()
            : 0.0;
        remaining -= lesson.durationHours;
        result[lesson.id] = _LessonStatus(
          balanceAfter: remaining,
          unpaidHours: unpaidHours,
        );
      }
    });

    return result;
  }

  Future<void> _showAddLesson(
    BuildContext context,
    List<Student> students,
    DateTime selectedDay, {
    DateTime? initialStart,
  }) async {
    if (students.isEmpty) {
      _showSnack(context, 'Add a student first before adding a lesson.');
      return;
    }
    Student? selectedStudent; // Start with no student selected
    final durationController = TextEditingController(text: '1');
    String lessonType = 'lesson';
    DateTime lessonDate = initialStart ?? selectedDay;
    TimeOfDay time = TimeOfDay.fromDateTime(
      initialStart ?? DateTime.now(),
    );
    final customTypes = List<CustomLessonType>.from(
      widget.instructor.instructorSettings?.customLessonTypes ?? [],
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogWidth =
                MediaQuery.sizeOf(context).width.clamp(320.0, 520.0);
            return AlertDialog(
              title: const Text('Add lesson'),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Autocomplete<Student>(
                        displayStringForOption: (student) => student.name,
                        optionsBuilder: (textEditingValue) {
                          final query =
                              textEditingValue.text.trim().toLowerCase();
                          if (query.isEmpty) {
                            return students;
                          }
                          return students.where(
                            (student) =>
                                student.name.toLowerCase().contains(query) ||
                                (student.email ?? '')
                                    .toLowerCase()
                                    .contains(query),
                          );
                        },
                        onSelected: (student) {
                          setDialogState(() => selectedStudent = student);
                        },
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Student',
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (hours)',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      _buildLessonTypeDropdown(
                        context,
                        lessonType,
                        customTypes,
                        (value) => setDialogState(() => lessonType = value),
                        setDialogState,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: lessonDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() => lessonDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text(
                          DateFormat('EEE, d MMM').format(lessonDate),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (picked != null) {
                            setDialogState(() => time = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          DateFormat('HH:mm').format(
                            DateTime(
                              lessonDate.year,
                              lessonDate.month,
                              lessonDate.day,
                              time.hour,
                              time.minute,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedStudent == null
                      ? null
                      : () async {
                          try {
                            final duration =
                                double.tryParse(durationController.text) ?? 1;
                            if (duration <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Duration must be greater than 0'),
                                ),
                              );
                              return;
                            }
                            final startAt = DateTime(
                              lessonDate.year,
                              lessonDate.month,
                              lessonDate.day,
                              time.hour,
                              time.minute,
                            );
                            final lesson = Lesson(
                              id: '',
                              instructorId: widget.instructor.id,
                              studentId: selectedStudent!.id,
                              schoolId: widget.instructor.schoolId,
                              startAt: startAt,
                              durationHours: duration,
                              lessonType: lessonType,
                              notes: null,
                            );
                            await _firestoreService.addLesson(
                              lesson: lesson,
                              studentId: selectedStudent!.id,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              // Navigate to the week containing the lesson if it's not the current week
                              final lessonWeekStart = _startOfWeek(startAt);
                              final currentWeekStart = _startOfWeek(_focusedDay);
                              if (!_isSameDay(lessonWeekStart, currentWeekStart)) {
                                setState(() {
                                  _focusedDay = startAt;
                                  _selectedDay = startAt;
                                  _didAutoScroll = false;
                                });
                              }
                            }
                          } catch (e) {
                            debugPrint('[calendar] Error adding lesson: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add lesson: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditLesson(
    BuildContext context,
    Lesson lesson,
    List<Student> students,
  ) async {
    if (students.isEmpty) {
      _showSnack(context, 'Add a student first.');
      return;
    }
    Student selectedStudent = students.firstWhere(
      (student) => student.id == lesson.studentId,
      orElse: () => students.first,
    );
    final durationController = TextEditingController(
      text: lesson.durationHours.toStringAsFixed(1),
    );
    String lessonType = lesson.lessonType;
    DateTime lessonDate = lesson.startAt;
    TimeOfDay time = TimeOfDay.fromDateTime(lesson.startAt);
    bool saving = false;
    final customTypes = List<CustomLessonType>.from(
      widget.instructor.instructorSettings?.customLessonTypes ?? [],
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogWidth =
                MediaQuery.sizeOf(context).width.clamp(320.0, 520.0);
            return AlertDialog(
              title: const Text('Edit lesson'),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Autocomplete<Student>(
                        displayStringForOption: (student) => student.name,
                        initialValue:
                            TextEditingValue(text: selectedStudent.name),
                        optionsBuilder: (textEditingValue) {
                          final query =
                              textEditingValue.text.trim().toLowerCase();
                          if (query.isEmpty) {
                            return students;
                          }
                          return students.where(
                            (student) =>
                                student.name.toLowerCase().contains(query) ||
                                (student.email ?? '')
                                    .toLowerCase()
                                    .contains(query),
                          );
                        },
                        onSelected: (student) {
                          setDialogState(() => selectedStudent = student);
                        },
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Student',
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (hours)',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      _buildLessonTypeDropdown(
                        context,
                        lessonType,
                        customTypes,
                        (value) => setDialogState(() => lessonType = value),
                        setDialogState,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: lessonDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() => lessonDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text(
                          DateFormat('EEE, d MMM').format(lessonDate),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (picked != null) {
                            setDialogState(() => time = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          DateFormat('HH:mm').format(
                            DateTime(
                              lessonDate.year,
                              lessonDate.month,
                              lessonDate.day,
                              time.hour,
                              time.minute,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final confirmed = await _confirmDeleteLesson(
                            context,
                            lesson,
                          );
                          if (confirmed && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Delete'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final duration =
                              double.tryParse(durationController.text) ?? 1;
                          setDialogState(() => saving = true);
                          final startAt = DateTime(
                            lessonDate.year,
                            lessonDate.month,
                            lessonDate.day,
                            time.hour,
                            time.minute,
                          );
                          if (selectedStudent.id != lesson.studentId) {
                            final newLesson = Lesson(
                              id: '',
                              instructorId: lesson.instructorId,
                              studentId: selectedStudent.id,
                              schoolId: widget.instructor.schoolId,
                              startAt: startAt,
                              durationHours: duration,
                              lessonType: lessonType,
                              notes: lesson.notes,
                            );
                            await _firestoreService.deleteLesson(lesson);
                            await _firestoreService.addLesson(
                              lesson: newLesson,
                              studentId: selectedStudent.id,
                            );
                          } else {
                            final updated = Lesson(
                              id: lesson.id,
                              instructorId: lesson.instructorId,
                              studentId: lesson.studentId,
                              schoolId: widget.instructor.schoolId,
                              startAt: startAt,
                              durationHours: duration,
                              lessonType: lessonType,
                              notes: lesson.notes,
                            );
                            await _firestoreService.updateLesson(
                              lesson: updated,
                              previousDuration: lesson.durationHours,
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteLesson(
    BuildContext context,
    Lesson lesson,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete lesson?'),
          content: const Text('This will remove the lesson and restore hours.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _firestoreService.deleteLesson(lesson);
      return true;
    }
    return false;
  }
}

class _LessonStatus {
  const _LessonStatus({
    required this.balanceAfter,
    required this.unpaidHours,
  });

  final double balanceAfter;
  final double unpaidHours;
}

enum _LessonPaymentState {
  paid,
  unpaid,
  pending,
}

class _NowIndicator extends StatefulWidget {
  const _NowIndicator({
    required this.weekDays,
    required this.dayWidth,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
  });

  final List<DateTime> weekDays;
  final double dayWidth;
  final int startHour;
  final int endHour;
  final double hourHeight;

  @override
  State<_NowIndicator> createState() => _NowIndicatorState();
}

class _NowIndicatorState extends State<_NowIndicator> {
  Timer? _timer;

  bool _isSameDay(DateTime a, DateTime b) {
    // Normalize both dates to local time and compare only date components
    final aLocal = DateTime(a.year, a.month, a.day);
    final bLocal = DateTime(b.year, b.month, b.day);
    return aLocal == bLocal;
  }

  @override
  void initState() {
    super.initState();
    // Update every minute to move the indicator
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = widget.weekDays.indexWhere((day) => _isSameDay(day, now));
    if (todayIndex < 0) {
      return const SizedBox.shrink();
    }
    final minutesFromStart =
        (now.hour * 60 + now.minute) - (widget.startHour * 60);
    if (minutesFromStart < 0 ||
        minutesFromStart > (widget.endHour - widget.startHour) * 60) {
      return const SizedBox.shrink();
    }
    final top = (minutesFromStart / 60) * widget.hourHeight;
    final left = todayIndex * widget.dayWidth;
    return Positioned(
      top: top,
      left: left,
      width: widget.dayWidth,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 2,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
