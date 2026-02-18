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
    this.showAppBar = true,
  });

  final String studentId;
  final String studentName;
  final String instructorId;
  final bool readOnly;
  final bool showAppBar;

  @override
  State<StudentCompetenciesScreen> createState() => _StudentCompetenciesScreenState();
}

class _StudentCompetenciesScreenState extends State<StudentCompetenciesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('${widget.studentName} - Progress'),
              surfaceTintColor: Colors.transparent,
            )
          : null,
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

          // Calculate overall stats
          final allSkills = Competency.predefinedSkills;
          final ratedSkills = competencyMap.values.where((c) => c.rating > 0).length;
          final averageRating = ratedSkills > 0
              ? competencyMap.values
                    .where((c) => c.rating > 0)
                    .fold(0, (sum, c) => sum + c.rating) /
                  ratedSkills
              : 0.0;
          final independentCount =
              competencyMap.values.where((c) => c.rating >= 5).length;
          final overallProgress = allSkills.isEmpty ? 0.0 : independentCount / allSkills.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overall progress card
              _buildOverallCard(
                context,
                ratedSkills: ratedSkills,
                totalSkills: allSkills.length,
                averageRating: averageRating,
                independentCount: independentCount,
                overallProgress: overallProgress,
              ),
              const SizedBox(height: 8),
              // DVSA scale legend
              _buildLegend(context),
              const SizedBox(height: 16),
              // Sections
              ...Competency.skillSections.map((section) => _buildSection(
                    context,
                    section,
                    competencyMap,
                  )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverallCard(
    BuildContext context, {
    required int ratedSkills,
    required int totalSkills,
    required double averageRating,
    required int independentCount,
    required double overallProgress,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Progress',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(overallProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Test Ready',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('Skills Rated', '$ratedSkills/$totalSkills'),
              _buildMiniStat('Avg Rating', averageRating.toStringAsFixed(1)),
              _buildMiniStat('Independent', '$independentCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DVSA Progress Scale',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(5, (i) {
              final level = i + 1;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _ratingColor(level),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$level: ${Competency.ratingLabel(level)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    SkillSection section,
    Map<String, Competency> competencyMap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate section progress
    final sectionRated = section.skills
        .where((s) => (competencyMap[s]?.rating ?? 0) > 0)
        .length;
    final sectionIndependent = section.skills
        .where((s) => (competencyMap[s]?.rating ?? 0) >= 5)
        .length;
    final sectionProgress =
        section.skills.isEmpty ? 0.0 : sectionIndependent / section.skills.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _sectionColor(sectionProgress).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _sectionIcon(section.icon),
                  color: _sectionColor(sectionProgress),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$sectionRated/${section.skills.length} rated · $sectionIndependent independent',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Section progress ring
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: sectionProgress,
                      strokeWidth: 3,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _sectionColor(sectionProgress),
                      ),
                    ),
                    Text(
                      '${(sectionProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Skills within section
        ...section.skills.map((skill) {
          final competency = competencyMap[skill];
          final rating = competency?.rating ?? 0;
          return _buildSkillCard(context, skill, rating, competency);
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSkillCard(
    BuildContext context,
    String skill,
    int rating,
    Competency? competency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    skill,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // Rating label chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _ratingColor(rating).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Competency.ratingLabel(rating),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _ratingColor(rating),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Star rating
            Row(
              children: [
                _buildStarRating(
                  rating,
                  widget.readOnly
                      ? null
                      : (newRating) => _updateRating(skill, newRating, competency),
                ),
                const Spacer(),
                if (!widget.readOnly)
                  GestureDetector(
                    onTap: () => _editNotes(skill, competency),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          competency?.notes?.isNotEmpty == true
                              ? Icons.note_rounded
                              : Icons.note_add_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          competency?.notes?.isNotEmpty == true ? 'Edit notes' : 'Add notes',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // Progress bar
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rating / 5.0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_ratingColor(rating)),
                minHeight: 4,
              ),
            ),
            if (competency?.notes != null && competency!.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                competency.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
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
            color: starIndex <= rating ? _ratingColor(rating) : Colors.grey.shade400,
            size: 26,
          ),
        );
      }),
    );
  }

  Color _ratingColor(int rating) {
    switch (rating) {
      case 5:
        return AppTheme.success;
      case 4:
        return const Color(0xFF22D3EE); // cyan
      case 3:
        return AppTheme.info;
      case 2:
        return AppTheme.warning;
      case 1:
        return AppTheme.error;
      default:
        return Colors.grey.shade400;
    }
  }

  Color _sectionColor(double progress) {
    if (progress >= 0.8) return AppTheme.success;
    if (progress >= 0.5) return AppTheme.info;
    if (progress >= 0.2) return AppTheme.warning;
    return Colors.grey.shade500;
  }

  IconData _sectionIcon(String iconName) {
    switch (iconName) {
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'visibility':
        return Icons.visibility_rounded;
      case 'turn_right':
        return Icons.turn_right_rounded;
      case 'swap_calls':
        return Icons.swap_calls_rounded;
      case 'road':
        return Icons.add_road_rounded;
      case 'wb_cloudy':
        return Icons.wb_cloudy_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      default:
        return Icons.circle;
    }
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
