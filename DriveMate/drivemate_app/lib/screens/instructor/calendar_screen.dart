import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/lesson.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
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

  static const int _startHour = 0;
  static const int _endHour = 24;
  static const int _defaultScrollHour = 6;
  static const double _hourHeight = 70;
  static const double _timeColumnWidth = 40;
  static const double _compactBreakpoint = 380;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _didAutoScroll = false;
  bool _showList = false;
  late final ScrollController _verticalController;
  late final ScrollController _headerScrollController;
  late final ScrollController _gridScrollController;
  bool _syncingScroll = false;
  Timer? _nowTicker;

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
    _nowTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nowTicker?.cancel();
    _verticalController.dispose();
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _firestoreService.streamStudents(widget.instructor.id),
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
              _firestoreService.streamLessonsForInstructor(widget.instructor.id),
          builder: (context, lessonSnapshot) {
            if (lessonSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading lessons...');
            }
            final lessons = lessonSnapshot.data ?? [];
            return StreamBuilder<List<Payment>>(
              stream: _firestoreService
                  .streamPaymentsForInstructor(widget.instructor.id),
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
                return Scaffold(
                  body: Column(
                    children: [
                      _buildViewToggle(context),
                      _buildWeekHeader(context, weekDays, selectedDay),
                      Expanded(
                        child: _showList
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

  Widget _buildViewToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ToggleButtons(
            isSelected: [_showList == false, _showList == true],
            onPressed: (index) {
              setState(() => _showList = index == 1);
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Icon(Icons.grid_view, size: 16),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Icon(Icons.view_list, size: 16),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                _selectedDay = _focusedDay;
                _didAutoScroll = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.add(const Duration(days: 7));
                _selectedDay = _focusedDay;
                _didAutoScroll = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekGrid(
    BuildContext context,
    List<DateTime> weekDays,
    List<Lesson> lessons,
    List<Student> students,
    Map<String, String> studentMap,
    DateTime selectedDay,
    Map<String, _LessonStatus> lessonStatuses,
  ) {
    final totalHours = _endHour - _startHour;
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
                _buildTimeColumn(totalHours),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _gridScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      child: Stack(
                        children: [
                          _buildGridBackground(
                            context,
                            weekDays,
                            totalHours,
                            selectedDay,
                          ),
                          _buildNowIndicator(weekDays, dayWidth),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (details) {
                                if (students.isEmpty) return;
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
                                final totalMinutes = (_startHour * 60) +
                                    snappedMinutes.clamp(
                                      0,
                                      (_endHour - _startHour) * 60 - 1,
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
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(studentName),
          subtitle: Text(
            '${DateFormat('EEE, d MMM').format(lesson.startAt)} · '
            '${DateFormat('HH:mm').format(lesson.startAt)} · '
            '$statusLabel',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                _openStudentProfile(
                  context,
                  lesson.studentId,
                  studentName,
                );
              } else if (value == 'edit') {
                _showEditLesson(context, lesson, students);
              } else if (value == 'delete') {
                _confirmDeleteLesson(context, lesson);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: const Text('Profile'),
              ),
              PopupMenuItem(
                value: 'edit',
                child: const Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: const Text('Delete'),
              ),
              if (paymentState == _LessonPaymentState.unpaid)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Unpaid',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeColumn(int totalHours) {
    final columnHeight = totalHours * _hourHeight;
    return SizedBox(
      width: _timeColumnWidth,
      height: columnHeight,
      child: Column(
        children: List.generate(
          totalHours,
          (index) {
            final hour = _startHour + index;
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
  ) {
    _maybeAutoScrollToLessons(lessons, weekDays);
    return lessons
        .where((lesson) =>
            weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .map((lesson) {
      final dayIndex = weekDays.indexWhere(
        (day) => _isSameDay(day, lesson.startAt),
      );
      if (dayIndex < 0) return const SizedBox.shrink();
      final startMinutes =
          (lesson.startAt.hour * 60 + lesson.startAt.minute) -
              (_startHour * 60);
      final top = (startMinutes / 60) * _hourHeight;
      if (top < 0 || top > (_endHour - _startHour) * _hourHeight) {
        debugPrint(
          '[calendar] lesson out of range id=${lesson.id} '
          'start=${lesson.startAt.toIso8601String()} '
          'range=${_startHour.toString().padLeft(2, '0')}:00-'
          '${_endHour.toString().padLeft(2, '0')}:00',
        );
        return const SizedBox.shrink();
      }
      final height = lesson.durationHours * _hourHeight;
      final left = dayIndex * dayWidth + 4;
      final status = lessonStatuses[lesson.id];
      final unpaidHours = status?.unpaidHours ?? 0;
      final paymentState = _resolvePaymentState(status);
      final isPast = _isLessonPast(lesson);
      final backgroundColor = _lessonColor(
        lessonType: lesson.lessonType,
        isPast: isPast,
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
        top: top,
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
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
  }) {
    final base = switch (lessonType) {
      'mock_test' => Colors.deepPurple,
      'test' => Colors.blue,
      _ => Colors.orange,
    };
    return base.withOpacity(isPast ? 0.85 : 0.9);
  }

  String _lessonTypeLabel(String lessonType) {
    switch (lessonType) {
      case 'mock_test':
        return 'Mock test';
      case 'test':
        return 'Driving test';
      default:
        return 'Lesson';
    }
  }

  Widget _buildNowIndicator(List<DateTime> weekDays, double dayWidth) {
    final now = DateTime.now();
    final todayIndex = weekDays.indexWhere((day) => _isSameDay(day, now));
    if (todayIndex < 0) {
      return const SizedBox.shrink();
    }
    final minutesFromStart =
        (now.hour * 60 + now.minute) - (_startHour * 60);
    if (minutesFromStart < 0 ||
        minutesFromStart > (_endHour - _startHour) * 60) {
      return const SizedBox.shrink();
    }
    final top = (minutesFromStart / 60) * _hourHeight;
    final left = todayIndex * dayWidth;
    return Positioned(
      top: top,
      left: left,
      width: dayWidth,
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
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: Text(studentName),
                onTap: () {
                  Navigator.pop(context);
                  _openStudentProfile(
                    parentContext,
                    lesson.studentId,
                    studentName,
                  );
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
                leading: const Icon(Icons.delete),
                title: const Text('Delete lesson'),
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _maybeAutoScrollToLessons(
    List<Lesson> lessons,
    List<DateTime> weekDays,
  ) {
    if (_didAutoScroll || !_verticalController.hasClients) return;
    final weekLessons = lessons
        .where((lesson) => weekDays.any((day) => _isSameDay(day, lesson.startAt)))
        .toList();
    final defaultHour =
        _defaultScrollHour.clamp(_startHour, _endHour - 1).toInt();
    final defaultMinutesFromStart = (defaultHour - _startHour) * 60;
    var targetMinutesFromStart = defaultMinutesFromStart;
    if (weekLessons.isNotEmpty) {
      weekLessons.sort((a, b) => a.startAt.compareTo(b.startAt));
      final first = weekLessons.first.startAt;
      final firstMinutesFromStart =
          (first.hour * 60 + first.minute) - (_startHour * 60);
      if (firstMinutesFromStart < 0) return;
      if (firstMinutesFromStart < defaultMinutesFromStart) {
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
    Student selectedStudent = students.first;
    final durationController = TextEditingController(text: '1');
    String lessonType = 'lesson';
    DateTime lessonDate = initialStart ?? selectedDay;
    TimeOfDay time = TimeOfDay.fromDateTime(
      initialStart ?? DateTime.now(),
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
                      DropdownButtonFormField<String>(
                        value: lessonType,
                        decoration:
                            const InputDecoration(labelText: 'Lesson type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'lesson',
                            child: Text('Driving lesson'),
                          ),
                          DropdownMenuItem(
                            value: 'test',
                            child: Text('Driving test'),
                          ),
                          DropdownMenuItem(
                            value: 'mock_test',
                            child: Text('Mock test'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => lessonType = value);
                          }
                        },
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
                  onPressed: () async {
                    final duration =
                        double.tryParse(durationController.text) ?? 1;
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
                      studentId: selectedStudent.id,
                      schoolId: widget.instructor.schoolId,
                      startAt: startAt,
                      durationHours: duration,
                      lessonType: lessonType,
                      notes: null,
                    );
                    await _firestoreService.addLesson(
                      lesson: lesson,
                      studentId: selectedStudent.id,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
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
                      DropdownButtonFormField<String>(
                        value: lessonType,
                        decoration:
                            const InputDecoration(labelText: 'Lesson type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'lesson',
                            child: Text('Driving lesson'),
                          ),
                          DropdownMenuItem(
                            value: 'test',
                            child: Text('Driving test'),
                          ),
                          DropdownMenuItem(
                            value: 'mock_test',
                            child: Text('Mock test'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => lessonType = value);
                          }
                        },
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
