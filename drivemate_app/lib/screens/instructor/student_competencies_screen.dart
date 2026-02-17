import 'package:flutter/material.dart';

import '../../models/competency.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class StudentCompetenciesScreen extends StatefulWidget {
  const StudentCompetenciesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.instructorId,
    this.readOnly = false,
  });

  final String studentId;
  final String studentName;
  final String instructorId;
  final bool readOnly;

  @override
  State<StudentCompetenciesScreen> createState() => _StudentCompetenciesScreenState();
}

class _StudentCompetenciesScreenState extends State<StudentCompetenciesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - Progress'),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Competency>>(
        stream: _firestoreService.streamCompetencies(
          studentId: widget.studentId,
          instructorId: widget.instructorId,
        ),
        builder: (context, snapshot) {
          final competencies = snapshot.data ?? [];
          final competencyMap = {
            for (var c in competencies) c.skill: c,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overall progress
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildOverallProgress(competencyMap, colorScheme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Skills Assessment',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...Competency.predefinedSkills.map((skill) {
                final competency = competencyMap[skill];
                final rating = competency?.rating ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                skill,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            _buildStarRating(
                              rating,
                              widget.readOnly
                                  ? null
                                  : (newRating) => _updateRating(skill, newRating, competency),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: rating / 5.0,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rating >= 4
                                  ? AppTheme.success
                                  : rating >= 2
                                      ? AppTheme.warning
                                      : colorScheme.outlineVariant,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        if (competency?.notes != null && competency!.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            competency.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (!widget.readOnly) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _editNotes(skill, competency),
                            child: Text(
                              competency?.notes?.isNotEmpty == true ? 'Edit notes' : 'Add notes',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverallProgress(Map<String, Competency> competencyMap, ColorScheme colorScheme) {
    final totalSkills = Competency.predefinedSkills.length;
    final ratedSkills = competencyMap.values.where((c) => c.rating > 0).length;
    final averageRating = ratedSkills > 0
        ? competencyMap.values.fold(0, (sum, c) => sum + c.rating) / ratedSkills
        : 0.0;
    final progress = ratedSkills / totalSkills;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Skills Rated', '$ratedSkills / $totalSkills', colorScheme),
            _buildStat('Avg Rating', averageRating.toStringAsFixed(1), colorScheme),
            _buildStat('Progress', '${(progress * 100).toInt()}%', colorScheme),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.8 ? AppTheme.success : AppTheme.primary,
            ),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStarRating(int rating, void Function(int)? onTap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        return GestureDetector(
          onTap: onTap != null ? () => onTap(starIndex) : null,
          child: Icon(
            starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: starIndex <= rating ? Colors.amber : Colors.grey.shade400,
            size: 28,
          ),
        );
      }),
    );
  }

  Future<void> _updateRating(String skill, int rating, Competency? existing) async {
    try {
      await _firestoreService.upsertCompetency(Competency(
        id: existing?.id ?? '',
        studentId: widget.studentId,
        instructorId: widget.instructorId,
        skill: skill,
        rating: rating,
        notes: existing?.notes,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e')),
        );
      }
    }
  }

  Future<void> _editNotes(String skill, Competency? existing) async {
    final controller = TextEditingController(text: existing?.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(skill),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestoreService.upsertCompetency(Competency(
          id: existing?.id ?? '',
          studentId: widget.studentId,
          instructorId: widget.instructorId,
          skill: skill,
          rating: existing?.rating ?? 0,
          notes: result.isEmpty ? null : result,
        ));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving notes: $e')),
          );
        }
      }
    }
  }
}
