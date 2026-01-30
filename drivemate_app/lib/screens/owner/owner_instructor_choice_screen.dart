import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import 'owner_home.dart';
import '../instructor/instructor_home.dart';

/// Shown when the user is both owner and instructor. Lets them choose which
/// profile to open and allows switching between Owner and Instructor views.
class OwnerInstructorChoiceScreen extends StatelessWidget {
  const OwnerInstructorChoiceScreen({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  static void openAsOwner(BuildContext context, UserProfile profile) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OwnerHome(profile: profile),
      ),
    );
  }

  static void openAsInstructor(BuildContext context, UserProfile profile) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InstructorHome(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Open as',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can switch between these views anytime from the menu.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _ChoiceCard(
                icon: Icons.business_rounded,
                title: 'Owner',
                subtitle: 'Manage school, instructors, access requests and reports',
                onTap: () => openAsOwner(context, profile),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                icon: Icons.school_rounded,
                title: 'Instructor',
                subtitle: 'Calendar, students, payments and lessons',
                onTap: () => openAsInstructor(context, profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
