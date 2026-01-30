import 'package:flutter/material.dart';

import '../../../models/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../../appearance_screen.dart';
import 'cancellation_settings_screen.dart';
import 'calendar_settings_screen.dart';
import 'navigation_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsMainScreen extends StatelessWidget {
  const SettingsMainScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSection(
            context,
            title: 'Notifications',
            subtitle: 'Reminders and auto-notifications',
            icon: Icons.notifications_outlined,
            iconColor: AppTheme.primary,
            iconBgColor: AppTheme.primary.withOpacity(0.1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationSettingsScreen(instructor: instructor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsSection(
            context,
            title: 'Cancellations',
            subtitle: 'Cancellation rules and charges',
            icon: Icons.event_busy_rounded,
            iconColor: AppTheme.warning,
            iconBgColor: AppTheme.warningLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CancellationSettingsScreen(instructor: instructor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsSection(
            context,
            title: 'Calendar',
            subtitle: 'View preferences and lesson colors',
            icon: Icons.calendar_today_outlined,
            iconColor: AppTheme.secondary,
            iconBgColor: AppTheme.secondaryLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarSettingsScreen(instructor: instructor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsSection(
            context,
            title: 'Navigation',
            subtitle: 'Default navigation app',
            icon: Icons.navigation_rounded,
            iconColor: AppTheme.info,
            iconBgColor: AppTheme.infoLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NavigationSettingsScreen(instructor: instructor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsSection(
            context,
            title: 'Appearance',
            subtitle: 'Light, dark, or system theme',
            icon: Icons.palette_outlined,
            iconColor: AppTheme.primary,
            iconBgColor: AppTheme.primary.withOpacity(0.1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppearanceScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
