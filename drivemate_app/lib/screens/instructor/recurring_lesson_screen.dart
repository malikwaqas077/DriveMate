import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/recurring_template.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class RecurringLessonScreen extends StatefulWidget {
  const RecurringLessonScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<RecurringLessonScreen> createState() => _RecurringLessonScreenState();
}

class _RecurringLessonScreenState extends State<RecurringLessonScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Student? _selectedStudent;
  int _dayOfWeek = DateTime.monday;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  double _durationHours = 1.0;
  String _lessonType = 'lesson';
  int _weeks = 4;
  bool _isGenerating = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Lessons'),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Student>>(
        stream: _firestoreService.streamStudents(widget.instructor.id),
        builder: (context, snapshot) {
          final students = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Student picker
              Text('Student', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Autocomplete<Student>(
                displayStringForOption: (s) => s.name,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return students;
                  return students.where((s) => s.name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (student) {
                  setState(() => _selectedStudent = student);
                },
                fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Select a student...',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Day of week chips
              Text('Day of Week', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final isSelected = _dayOfWeek == day;
                  return ChoiceChip(
                    label: Text(_dayNames[i]),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _dayOfWeek = day),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Time picker
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Time', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(_startTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (time != null) {
                              setState(() => _startTime = time);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duration', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<double>(
                          value: _durationHours,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0.5, child: Text('30 min')),
                            DropdownMenuItem(value: 1.0, child: Text('1 hour')),
                            DropdownMenuItem(value: 1.5, child: Text('1.5 hours')),
                            DropdownMenuItem(value: 2.0, child: Text('2 hours')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _durationHours = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Lesson type
              Text('Lesson Type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _lessonType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'lesson', child: Text('Lesson')),
                  DropdownMenuItem(value: 'test', child: Text('Test')),
                  DropdownMenuItem(value: 'mock_test', child: Text('Mock Test')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _lessonType = v);
                },
              ),
              const SizedBox(height: 20),

              // Weeks count
              Text('Number of Weeks', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _weeks > 1 ? () => setState(() => _weeks--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_weeks weeks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _weeks < 52 ? () => setState(() => _weeks++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateLessons,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isGenerating
                      ? 'Generating...'
                      : 'Generate $_weeks Lessons'),
                ),
              ),
              const SizedBox(height: 16),

              // Saved templates
              const Divider(),
              const SizedBox(height: 16),
              Text('Saved Templates', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<List<RecurringTemplate>>(
                stream: _firestoreService.streamRecurringTemplates(widget.instructor.id),
                builder: (context, templateSnap) {
                  final templates = templateSnap.data ?? [];
                  if (templates.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No saved templates yet',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: templates.map((t) {
                      final studentName = students
                          .where((s) => s.id == t.studentId)
                          .map((s) => s.name)
                          .firstOrNull ?? 'Unknown';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(_dayNames[t.dayOfWeek - 1]),
                          ),
                          title: Text('$studentName - ${_dayNames[t.dayOfWeek - 1]}'),
                          subtitle: Text(
                            '${t.startHour.toString().padLeft(2, '0')}:${t.startMinute.toString().padLeft(2, '0')} - ${t.durationHours}h - ${t.repeatCount}x ${t.frequencyLabel}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                            onPressed: () => _firestoreService.deleteRecurringTemplate(t.id),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateLessons() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final template = RecurringTemplate(
        id: '',
        instructorId: widget.instructor.id,
        studentId: _selectedStudent!.id,
        dayOfWeek: _dayOfWeek,
        startHour: _startTime.hour,
        startMinute: _startTime.minute,
        durationHours: _durationHours,
        lessonType: _lessonType,
        repeatCount: _weeks,
      );

      // Save template
      await _firestoreService.saveRecurringTemplate(template);

      // Generate lessons starting from next occurrence
      final count = await _firestoreService.generateLessonsFromTemplate(
        template: template,
        startFromDate: DateTime.now(),
      );

      if (mounted) {
        final studentName = _selectedStudent!.name;
        final dayName = _dayNames[_dayOfWeek - 1];
        final timeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
        final weeksCount = _weeks;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count lessons created for $studentName'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'SHARE',
              textColor: Colors.white,
              onPressed: () => _shareBulkLessons(
                dayName: dayName,
                timeStr: timeStr,
                weeks: weeksCount,
                count: count,
              ),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareBulkLessons({
    required String dayName,
    required String timeStr,
    required int weeks,
    required int count,
  }) async {
    final message = 'Recurring lessons booked!\n'
        '$count lessons every $dayName at $timeStr for $weeks weeks.';
    await Share.share(message);
  }
}
