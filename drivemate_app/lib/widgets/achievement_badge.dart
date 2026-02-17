import 'package:flutter/material.dart';

import '../models/achievement.dart';

class AchievementBadgesWidget extends StatelessWidget {
  const AchievementBadgesWidget({
    super.key,
    required this.achievements,
    this.showLocked = true,
  });

  final List<Achievement> achievements;
  final bool showLocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final awardedTypes = achievements.map((a) => a.type).toSet();

    final allDefinitions = Achievement.definitions.values.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allDefinitions.map((def) {
        final isUnlocked = awardedTypes.contains(def.type);

        if (!isUnlocked && !showLocked) return const SizedBox.shrink();

        return Tooltip(
          message: '${def.title}\n${def.description}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnlocked
                    ? colorScheme.primary.withOpacity(0.3)
                    : colorScheme.outlineVariant,
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  def.icon,
                  style: TextStyle(
                    fontSize: 18,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  def.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.w400,
                    color: isUnlocked
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
