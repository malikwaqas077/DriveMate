import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/recurring_template.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import '../chat/chat_screen.dart';
import 'student_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();

  static const int _defaultStartHour = 6; // Default start hour (06:00)
  static const int _endHour = 24;
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

  // Drag-and-drop state
  String? _draggingLessonId;
  int? _dragTargetDayIndex;
  double? _dragTargetMinutes;

  // Cached streams - created once in initState
  late final Stream<UserProfile?> _instructorStream;
  late final Stream<List<Student>> _studentsStream;
  late final Stream<List<Lesson>> _lessonsStream;
  late final Stream<List<Payment>> _paymentsStream;

  // Cached data to avoid unnecessary rebuilds
  UserProfile? _cachedInstructor;
  List<Student> _cachedStudents = [];
  List<Lesson> _cachedLessons = [];
  List<Payment> _cachedPayments = [];
  bool _isLoading = true;

  // Stream subscriptions
  StreamSubscription<UserProfile?>? _instructorSubscription;
  StreamSubscription<List<Student>>? _studentsSubscription;
  StreamSubscription<List<Lesson>>? _lessonsSubscription;
  StreamSubscription<List<Payment>>? _paymentsSubscription;

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

    // Create streams once and cache them
    _instructorStream = _firestoreService.streamUserProfile(widget.instructor.id);
    _studentsStream = _firestoreService.streamStudents(widget.instructor.id);
    _lessonsStream = _firestoreService.streamLessonsForInstructor(widget.instructor.id);
    _paymentsStream = _firestoreService.streamPaymentsForInstructor(widget.instructor.id);

    // Subscribe to streams
    _setupStreamSubscriptions();
  }

  void _setupStreamSubscriptions() {
    _instructorSubscription = _instructorStream.listen((instructor) {
      if (!mounted) return;
      // Only update if data actually changed
      if (_instructorChanged(instructor)) {
        setState(() {
          _cachedInstructor = instructor;
        });
      }
    });

    _studentsSubscription = _studentsStream.listen((students) {
      if (!mounted) return;
      if (_studentsChanged(students)) {
        setState(() {
          _cachedStudents = students;
          _isLoading = false;
        });
      }
    });

    _lessonsSubscription = _lessonsStream.listen((lessons) {
      if (!mounted) return;
      if (_lessonsChanged(lessons)) {
        setState(() {
          _cachedLessons = lessons;
          _isLoading = false;
        });
      }
    });

    _paymentsSubscription = _paymentsStream.listen((payments) {
      if (!mounted) return;
      if (_paymentsChanged(payments)) {
        setState(() {
          _cachedPayments = payments;
        });
      }
    });
  }

  // Compare functions to prevent unnecessary rebuilds
  bool _instructorChanged(UserProfile? newInstructor) {
    if (_cachedInstructor == null && newInstructor == null) return false;
    if (_cachedInstructor == null || newInstructor == null) return true;
    return _cachedInstructor!.id != newInstructor.id ||
           _cachedInstructor!.instructorSettings?.defaultCalendarView != 
           newInstructor.instructorSettings?.defaultCalendarView ||
           _cachedInstructor!.instructorSettings?.lessonColors != 
           newInstructor.instructorSettings?.lessonColors;
  }

  bool _studentsChanged(List<Student> newStudents) {
    if (_cachedStudents.length != newStudents.length) return true;
    for (int i = 0; i < _cachedStudents.length; i++) {
      if (_cachedStudents[i].id != newStudents[i].id ||
          _cachedStudents[i].name != newStudents[i].name ||
          _cachedStudents[i].phone != newStudents[i].phone ||
          _cachedStudents[i].address != newStudents[i].address) {
        return true;
      }
    }
    return false;
  }

  bool _lessonsChanged(List<Lesson> newLessons) {
    if (_cachedLessons.length != newLessons.length) return true;
    for (int i = 0; i < _cachedLessons.length; i++) {
      if (_cachedLessons[i].id != newLessons[i].id ||
          _cachedLessons[i].startAt != newLessons[i].startAt ||
          _cachedLessons[i].durationHours != newLessons[i].durationHours ||
          _cachedLessons[i].studentId != newLessons[i].studentId ||
          _cachedLessons[i].status != newLessons[i].status ||
          _cachedLessons[i].testResult != newLessons[i].testResult) {
        return true;
      }
    }
    return false;
  }

  bool _paymentsChanged(List<Payment> newPayments) {
    if (_cachedPayments.length != newPayments.length) return true;
    for (int i = 0; i < _cachedPayments.length; i++) {
      if (_cachedPayments[i].id != newPayments[i].id ||
          _cachedPayments[i].hoursPurchased != newPayments[i].hoursPurchased) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _instructorSubscription?.cancel();
    _studentsSubscription?.cancel();
    _lessonsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _verticalController.dispose();
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cachedStudents.isEmpty && _cachedLessons.isEmpty) {
      return const LoadingView(message: 'Loading calendar...');
    }

    final instructor = _cachedInstructor ?? widget.instructor;
    final students = _cachedStudents;
    final lessons = _cachedLessons;
    final payments = _cachedPayments;
    final studentMap = {
      for (final student in students) student.id: student.name,
    };
    final lessonStatuses = _computeLessonStatuses(lessons, payments);
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
                      child: DragTarget<Lesson>(
                        onMove: (details) {
                          final renderBox = context.findRenderObject() as RenderBox?;
                          if (renderBox == null) return;
                          final local = renderBox.globalToLocal(details.offset);
                          // Account for time column width and scroll offset
                          final adjustedX = local.dx - _timeColumnWidth + (_gridScrollController.hasClients ? _gridScrollController.offset : 0);
                          final adjustedY = local.dy + (_verticalController.hasClients ? _verticalController.offset : 0);
                          final di = (adjustedX / dayWidth).floor().clamp(0, weekDays.length - 1);
                          final minutesFromStart = (adjustedY / _hourHeight * 60).round();
                          final snapped = ((minutesFromStart / 15).round() * 15).clamp(0, (_endHour - startHour) * 60 - 15);
                          final totalMins = (startHour * 60) + snapped;
                          if (di != _dragTargetDayIndex || totalMins.toDouble() != _dragTargetMinutes) {
                            setState(() {
                              _dragTargetDayIndex = di;
                              _dragTargetMinutes = totalMins.toDouble();
                            });
                          }
                        },
                        onLeave: (_) {
                          setState(() {
                            _dragTargetDayIndex = null;
                            _dragTargetMinutes = null;
                          });
                        },
                        onAcceptWithDetails: (details) async {
                          final lesson = details.data;
                          if (_dragTargetDayIndex == null || _dragTargetMinutes == null) return;
                          final targetDay = weekDays[_dragTargetDayIndex!];
                          final targetHour = _dragTargetMinutes!.toInt() ~/ 60;
                          final targetMinute = _dragTargetMinutes!.toInt() % 60;
                          final newStart = DateTime(
                            targetDay.year,
                            targetDay.month,
                            targetDay.day,
                            targetHour,
                            targetMinute,
                          );
                          // Skip if same position
                          if (newStart == lesson.startAt) return;
                          try {
                            final updated = lesson.copyWith(startAt: newStart);
                            await _firestoreService.updateLesson(
                              lesson: updated,
                              previousDuration: lesson.durationHours,
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to reschedule: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Stack(
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
                              // Drop target highlight
                              if (_draggingLessonId != null && _dragTargetDayIndex != null && _dragTargetMinutes != null)
                                Positioned(
                                  top: ((_dragTargetMinutes! - startHour * 60) / 60) * _hourHeight,
                                  left: _dragTargetDayIndex! * dayWidth + 1,
                                  width: dayWidth - 2,
                                  height: _hourHeight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.primary.withOpacity(0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_draggingLessonId == null)
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
                          );
                        },
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
    
    final filteredLessons = lessons
        .where((lesson) =>
            weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList();

    // Find the globally next upcoming lesson across ALL lessons (not just this week)
    final now = DateTime.now();
    String? nextUpcomingId;
    DateTime? nextUpcomingStart;
    for (final lesson in lessons) {
      if (lesson.status == 'scheduled' && lesson.startAt.isAfter(now)) {
        if (nextUpcomingStart == null || lesson.startAt.isBefore(nextUpcomingStart)) {
          nextUpcomingId = lesson.id;
          nextUpcomingStart = lesson.startAt;
        }
      }
    }
    
    return filteredLessons.map((lesson) {
      final dayIndex = weekDays.indexWhere(
        (day) => _isSameDay(day, lesson.startAt),
      );
      if (dayIndex < 0) {
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
        return const SizedBox.shrink();
      }
      
      // Clamp the top position to ensure it's visible
      final clampedTop = top.clamp(0.0, maxHeight);
      final height = lesson.durationHours * _hourHeight;
      final left = dayIndex * dayWidth + 4;
      final status = lessonStatuses[lesson.id];
      final unpaidHours = status?.unpaidHours ?? 0;
      final paymentState = _resolvePaymentState(status);
      final isPast = _isLessonPast(lesson);
      final backgroundColor = _lessonColor(
        lessonType: lesson.lessonType,
        lessonStatus: lesson.status,
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
      // Bug 1.5: Highlight next upcoming lesson
      final isNextUpcoming = lesson.id == nextUpcomingId;
      final canDrag = lesson.status == 'scheduled' && !isPast;
      final tileContent = Container(
        decoration: isNextUpcoming
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade600.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isNextUpcoming ? 4 : 6),
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
              // Test result badge (pass/fail)
              if ((lesson.lessonType == 'test' || lesson.lessonType == 'mock_test') && lesson.testResult != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: lesson.testResult == 'pass' ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      lesson.testResult == 'pass' ? Icons.check : Icons.close,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Bug 1.5: "NEXT" badge on upcoming lesson
              if (isNextUpcoming)
                Positioned(
                  bottom: 20,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NEXT',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

      final tileWidget = canDrag
          ? LongPressDraggable<Lesson>(
              data: lesson,
              delay: const Duration(milliseconds: 400),
              feedback: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(6),
                child: Opacity(
                  opacity: 0.85,
                  child: SizedBox(
                    width: dayWidth - 2,
                    height: height,
                    child: tileContent,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: tileContent,
              ),
              onDragStarted: () {
                setState(() => _draggingLessonId = lesson.id);
              },
              onDragEnd: (_) {
                setState(() {
                  _draggingLessonId = null;
                  _dragTargetDayIndex = null;
                  _dragTargetMinutes = null;
                });
              },
              child: GestureDetector(
                onTap: () => _showLessonActions(
                  context,
                  lesson,
                  students,
                  studentMap,
                ),
                child: tileContent,
              ),
            )
          : GestureDetector(
              onTap: () => _showLessonActions(
                context,
                lesson,
                students,
                studentMap,
              ),
              child: tileContent,
            );

      return Positioned(
        top: clampedTop,
        left: dayIndex * dayWidth + 1,
        width: dayWidth - 2,
        height: height,
        child: tileWidget,
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
    required String lessonStatus,
    required bool isPast,
    UserProfile? instructor,
  }) {
    // If lesson is completed (either explicitly marked or past and not cancelled), show green
    final isCompleted = lessonStatus == 'completed' || 
        (isPast && lessonStatus == 'scheduled');
    
    // If cancelled, show grey
    if (lessonStatus == 'cancelled') {
      return Colors.grey.withOpacity(0.7);
    }
    
    // Completed lessons are green
    if (isCompleted) {
      return const Color(0xFF4CAF50).withOpacity(0.9); // Green
    }
    
    // Get custom colors from settings, or use defaults for scheduled lessons
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
    
    return base.withOpacity(0.9);
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

  Future<void> _openChatWithStudent(
    BuildContext context,
    String studentId,
    String studentName,
  ) async {
    try {
      final conversationId = await _chatService.getOrCreateConversation(
        instructorId: widget.instructor.id,
        studentId: studentId,
      );
      final conversation = await _chatService.getConversation(conversationId);
      if (conversation != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversation: conversation,
              profile: widget.instructor,
              otherUserName: studentName,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showTimedSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      controller.close();
    });
  }

  void _offerShareLessonWithStudent(
    Lesson lesson,
    String studentName,
  ) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Lesson created for $studentName'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'SHARE',
          onPressed: () => _shareLessonDetails(lesson),
        ),
      ),
    );
    // Ensure the snackbar is dismissed even if widget rebuilds interfere
    Future.delayed(const Duration(seconds: 3), () {
      controller.close();
    });
  }

  Future<void> _shareLessonDetails(Lesson lesson) async {
    final message = _formatLessonDetails(lesson);
    await Share.share(message);
  }

  String _formatLessonDetails(Lesson lesson) {
    final date = DateFormat('EEE, d MMM yyyy').format(lesson.startAt);
    final time = DateFormat('HH:mm').format(lesson.startAt);
    final endAt = lesson.startAt.add(
      Duration(minutes: (lesson.durationHours * 60).round()),
    );
    final endTime = DateFormat('HH:mm').format(endAt);
    final durationStr = lesson.durationHours == 1.0
        ? '1 hour'
        : '${lesson.durationHours} hours';
    final type = lesson.lessonType.replaceAll('_', ' ');
    return 'Lesson booked!\n'
        'Date: $date\n'
        'Time: $time - $endTime ($durationStr)\n'
        'Type: $type';
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
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
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
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _openChatWithStudent(parentContext, lesson.studentId, studentName);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 32, color: AppTheme.primary),
                                const SizedBox(height: 4),
                                const Text('Chat', style: TextStyle(fontSize: 12)),
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
                  ],
                  const Divider(),
                  _buildNotificationButtons(context, lesson, student),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.share, color: AppTheme.primary),
                    title: const Text('Share Lesson Details'),
                    onTap: () {
                      Navigator.pop(context);
                      _shareLessonDetails(lesson);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit lesson'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditLesson(parentContext, lesson, students);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.payment_rounded, color: AppTheme.success),
                    title: const Text('Record Payment'),
                    subtitle: Text('For $studentName'),
                    onTap: () {
                      Navigator.pop(context);
                      _showQuickPaymentDialog(
                        parentContext,
                        preselectedStudentId: lesson.studentId,
                        preselectedStudentName: studentName,
                      );
                    },
                  ),
                  if (lesson.lessonType == 'test' || lesson.lessonType == 'mock_test')
                    ListTile(
                      leading: Icon(
                        lesson.testResult == 'pass'
                            ? Icons.check_circle_rounded
                            : lesson.testResult == 'fail'
                                ? Icons.cancel_rounded
                                : Icons.grading_rounded,
                        color: lesson.testResult == 'pass'
                            ? AppTheme.success
                            : lesson.testResult == 'fail'
                                ? AppTheme.error
                                : AppTheme.info,
                      ),
                      title: Text(
                        lesson.testResult == 'pass'
                            ? 'Result: Pass'
                            : lesson.testResult == 'fail'
                                ? 'Result: Fail'
                                : 'Mark Pass / Fail',
                      ),
                      subtitle: lesson.testResult != null
                          ? const Text('Tap to change result')
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _showTestResultDialog(parentContext, lesson);
                      },
                    ),
                  if (lesson.status == 'scheduled')
                    ListTile(
                      leading: Icon(Icons.cancel_outlined, color: Colors.orange.shade700),
                      title: Text('Cancel Lesson', style: TextStyle(color: Colors.orange.shade700)),
                      onTap: () {
                        Navigator.pop(context);
                        _showCancelLessonDialog(parentContext, lesson, studentName);
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
            ),
          ),
        );
      },
    );
  }

  // Feature 2.1: Cancel Lesson Dialog
  Future<void> _showCancelLessonDialog(
    BuildContext context,
    Lesson lesson,
    String studentName,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel lesson with $studentName?'),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('EEE, MMM d').format(lesson.startAt)} at ${DateFormat('HH:mm').format(lesson.startAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Weather, illness...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Lesson'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            child: const Text('Cancel Lesson'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Update lesson status to cancelled
        await _firestoreService.updateLessonStatus(
          lessonId: lesson.id,
          status: 'cancelled',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Lesson cancelled'),
              backgroundColor: Colors.orange.shade700,
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
              content: Text('Error cancelling lesson: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showTestResultDialog(BuildContext context, Lesson lesson) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.infoLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grading_rounded, color: AppTheme.info, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Test Result')),
          ],
        ),
        content: const Text('How did the student do?'),
        actions: [
          if (lesson.testResult != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Clear Result'),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'fail'),
            icon: const Icon(Icons.cancel_rounded),
            label: const Text('Fail'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pass'),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Pass'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await _firestoreService.updateLessonTestResult(
          lessonId: lesson.id,
          testResult: result == 'clear' ? null : result,
        );
        if (mounted) {
          final message = result == 'clear'
              ? 'Test result cleared'
              : result == 'pass'
                  ? 'Marked as PASS'
                  : 'Marked as FAIL';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating test result: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  // Bug 1.7 / Feature 2.3: Quick Payment Dialog
  Future<void> _showQuickPaymentDialog(
    BuildContext context, {
    String? preselectedStudentId,
    String? preselectedStudentName,
  }) async {
    String? selectedStudentId = preselectedStudentId;
    String? selectedStudentName = preselectedStudentName;
    final amountController = TextEditingController();
    final hoursController = TextEditingController();
    String paymentMethod = 'cash';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment_rounded, color: AppTheme.success),
                      const SizedBox(width: 12),
                      Text(
                        'Quick Payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Student picker (if not preselected)
                  if (selectedStudentId == null)
                    Autocomplete<Student>(
                      displayStringForOption: (student) => student.name,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _cachedStudents;
                        }
                        return _cachedStudents.where((s) => s.name
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (student) {
                        setSheetState(() {
                          selectedStudentId = student.id;
                          selectedStudentName = student.name;
                        });
                      },
                      fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Student',
                            prefixIcon: Icon(Icons.person_rounded),
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Student',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(selectedStudentName ?? 'Unknown'),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount (£)',
                            prefixIcon: Icon(Icons.attach_money_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Hours',
                            prefixIcon: Icon(Icons.timer_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.wallet_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => paymentMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (selectedStudentId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a student')),
                          );
                          return;
                        }
                        final amount = double.tryParse(amountController.text.trim());
                        final hours = double.tryParse(hoursController.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }
                        if (hours == null || hours <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid hours')),
                          );
                          return;
                        }
                        try {
                          final payment = Payment(
                            id: '',
                            studentId: selectedStudentId!,
                            instructorId: widget.instructor.id,
                            amount: amount,
                            currency: 'GBP',
                            hoursPurchased: hours,
                            method: paymentMethod,
                            createdAt: DateTime.now(),
                            paidTo: 'instructor',
                          );
                          await _firestoreService.addPayment(
                            payment: payment,
                            studentId: selectedStudentId!,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment of £${amount.toStringAsFixed(0)} recorded for ${selectedStudentName ?? 'student'}'),
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
                                content: Text('Error recording payment: $e'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Record Payment'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
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

    // Scroll to current time and center it on screen
    final now = DateTime.now();
    final currentMinutesFromStart = (now.hour * 60 + now.minute) - (startHour * 60);
    final targetMinutesFromStart = currentMinutesFromStart.clamp(0, (_endHour - startHour) * 60);

    final top = (targetMinutesFromStart / 60) * _hourHeight;
    _didAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verticalController.hasClients) return;
      // Center the current time on screen
      final viewportHeight = _verticalController.position.viewportDimension;
      final offset = (top - viewportHeight / 2)
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

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    Student? selectedStudent;
    final durationController = TextEditingController(text: '1');
    String lessonType = 'lesson';
    DateTime lessonDate = initialStart ?? selectedDay;
    TimeOfDay time = TimeOfDay.fromDateTime(
      initialStart ?? DateTime.now(),
    );
    final customTypes = List<CustomLessonType>.from(
      widget.instructor.instructorSettings?.customLessonTypes ?? [],
    );

    // Recurrence state
    bool isRecurring = false;
    int repeatCount = 4;
    String frequency = 'weekly';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogWidth =
                MediaQuery.sizeOf(context).width.clamp(320.0, 520.0);
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: const Text('Add lesson'),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Repeat toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 20,
                              color: isRecurring
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Repeat',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isRecurring
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        value: isRecurring,
                        onChanged: (v) => setDialogState(() => isRecurring = v),
                      ),
                      if (isRecurring) ...[
                        const SizedBox(height: 8),
                        // Frequency selector
                        DropdownButtonFormField<String>(
                          value: frequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'everyOtherDay',
                              child: Text('Every other day'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'biweekly',
                              child: Text('Every 2 weeks'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => frequency = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Repeat',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: repeatCount > 2
                                  ? () => setDialogState(() => repeatCount--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 22,
                              visualDensity: VisualDensity.compact,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$repeatCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: repeatCount < 52
                                  ? () => setDialogState(() => repeatCount++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 22,
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              'times',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$repeatCount lessons will be created starting ${DateFormat('d MMM').format(lessonDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedStudent == null || isSaving
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
                            setDialogState(() => isSaving = true);
                            final startAt = DateTime(
                              lessonDate.year,
                              lessonDate.month,
                              lessonDate.day,
                              time.hour,
                              time.minute,
                            );

                            if (isRecurring) {
                              // Create recurring lessons
                              final template = RecurringTemplate(
                                id: '',
                                instructorId: widget.instructor.id,
                                studentId: selectedStudent!.id,
                                dayOfWeek: lessonDate.weekday,
                                startHour: time.hour,
                                startMinute: time.minute,
                                durationHours: duration,
                                lessonType: lessonType,
                                repeatCount: repeatCount,
                                frequency: frequency,
                              );
                              final count = await _firestoreService
                                  .generateLessonsFromTemplate(
                                template: template,
                                startFromDate: lessonDate,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              if (mounted) {
                                setState(() {
                                  _focusedDay = startAt;
                                  _selectedDay = startAt;
                                  _didAutoScroll = false;
                                });
                                _showTimedSnackBar(
                                  '$count lessons created for ${selectedStudent!.name}',
                                  backgroundColor: AppTheme.success,
                                );
                              }
                            } else {
                              // Create single lesson
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
                              }
                              if (mounted) {
                                final lessonWeekStart = _startOfWeek(startAt);
                                final currentWeekStart =
                                    _startOfWeek(_focusedDay);
                                if (!_isSameDay(
                                    lessonWeekStart, currentWeekStart)) {
                                  setState(() {
                                    _focusedDay = startAt;
                                    _selectedDay = startAt;
                                    _didAutoScroll = false;
                                  });
                                }
                                _offerShareLessonWithStudent(
                                  lesson,
                                  selectedStudent!.name,
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('[calendar] Error adding lesson: $e');
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add lesson: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isRecurring
                          ? 'Create $repeatCount Lessons'
                          : 'Save'),
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

class _NowIndicatorState extends State<_NowIndicator> with WidgetsBindingObserver {
  Timer? _timer;
  bool _isAppActive = true;

  bool _isSameDay(DateTime a, DateTime b) {
    // Normalize both dates to local time and compare only date components
    final aLocal = DateTime(a.year, a.month, a.day);
    final bLocal = DateTime(b.year, b.month, b.day);
    return aLocal == bLocal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // Update every minute to move the indicator
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isAppActive) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Stop timer when app goes to background
      _isAppActive = false;
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      // Restart timer when app comes back to foreground
      _isAppActive = true;
      if (mounted) {
        setState(() {}); // Refresh the indicator position
      }
      _startTimer();
    }
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
