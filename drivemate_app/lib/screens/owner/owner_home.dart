import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/role_preference_service.dart';
import '../../theme/app_theme.dart';
import 'owner_dashboard_screen.dart';
import 'owner_instructor_choice_screen.dart';
import 'owner_instructors_screen.dart';
import 'owner_reports_screen.dart';
import 'owner_settings_screen.dart';

class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final schoolId = profile.schoolId;
    final hasSchool = schoolId != null && schoolId.isNotEmpty;

    return FutureBuilder<bool>(
      future: hasSchool
          ? firestoreService.isOwnerAlsoInstructor(
              ownerId: profile.id,
              schoolId: schoolId,
            )
          : Future.value(false),
      builder: (context, snapshot) {
        final isAlsoInstructor = snapshot.data ?? false;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: _buildAppBar(context, isAlsoInstructor, authService),
            body: TabBarView(
              children: [
                OwnerDashboardScreen(owner: profile),
                OwnerInstructorsScreen(owner: profile),
                OwnerReportsScreen(owner: profile),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isAlsoInstructor,
    AuthService authService,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: context.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DriveMate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                profile.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: TabBar(
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
          Tab(icon: Icon(Icons.people_outline), text: 'Instructors'),
          Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Reports'),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(profile.name),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          offset: const Offset(0, 8),
          itemBuilder: (context) => [
            _buildPopupHeader(context),
            const PopupMenuDivider(),
            // Top 3 items: Settings, Log out, Switch to Instructor
            _buildPopupItem(
              context,
              icon: Icons.settings_outlined,
              label: 'Settings',
              value: 'settings',
            ),
            _buildPopupItem(
              context,
              icon: Icons.logout_rounded,
              label: 'Log out',
              value: 'logout',
              isDestructive: true,
            ),
            if (isAlsoInstructor) ...[
              const PopupMenuDivider(),
              _buildPopupItem(
                context,
                icon: Icons.swap_horiz_rounded,
                label: 'Switch to Instructor view',
                value: 'switch_instructor',
              ),
            ],
          ],
          onSelected: (value) async {
            if (value == 'settings') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerSettingsScreen(owner: profile),
                ),
              );
            }
            if (value == 'logout') {
              _showLogoutConfirmation(context, authService);
            }
            if (value == 'switch_instructor' && isAlsoInstructor) {
              // Save preference and switch
              RolePreferenceService.instance.savePreferredRole(profile.id, 'instructor');
              OwnerInstructorChoiceScreen.openAsInstructor(context, profile);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(profile.name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.email ?? '',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Owner',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? AppTheme.error : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? AppTheme.error : colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Log out?')),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of DriveMate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context);
              navigator.popUntil((route) => route.isFirst);
              await authService.signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
