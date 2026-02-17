import 'package:flutter/material.dart';

import '../../../models/user_profile.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _saving = false;

  late int _reminderHoursBefore;
  late bool _autoSendOnWay;
  late bool _autoSendArrived;
  // Feature 2.5: Low balance alerts
  late bool _lowBalanceAlertEnabled;
  late double _lowBalanceThresholdHours;

  static const List<int> reminderHoursOptions = [1, 2, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    final settings = widget.instructor.instructorSettings;

    _reminderHoursBefore = widget.instructor.getReminderHours();
    if (!reminderHoursOptions.contains(_reminderHoursBefore)) {
      _reminderHoursBefore = 24;
    }

    _autoSendOnWay = settings?.notificationSettings?['autoSendOnWay'] ?? false;
    _autoSendArrived = settings?.notificationSettings?['autoSendArrived'] ?? false;
    // Feature 2.5: Low balance alert settings
    _lowBalanceAlertEnabled = settings?.notificationSettings?['lowBalanceAlertEnabled'] == true;
    _lowBalanceThresholdHours = (settings?.notificationSettings?['lowBalanceThresholdHours'] as num?)?.toDouble() ?? 2.0;
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      final currentSettings = widget.instructor.instructorSettings;
      final settings = InstructorSettings(
        cancellationRules: currentSettings?.cancellationRules,
        reminderHoursBefore: _reminderHoursBefore,
        notificationSettings: {
          'autoSendOnWay': _autoSendOnWay,
          'autoSendArrived': _autoSendArrived,
          'lowBalanceAlertEnabled': _lowBalanceAlertEnabled,
          'lowBalanceThresholdHours': _lowBalanceThresholdHours,
        },
        defaultNavigationApp: currentSettings?.defaultNavigationApp,
        lessonColors: currentSettings?.lessonColors,
        defaultCalendarView: currentSettings?.defaultCalendarView,
      );

      await _firestoreService.updateUserProfile(widget.instructor.id, {
        'instructorSettings': settings.toMap(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Settings saved'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error saving settings: $e')),
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: 'Notifications',
                    subtitle: 'Configure automatic notifications and reminders',
                    icon: Icons.notifications_outlined,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withOpacity(0.1),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingCard(
                    children: [
                      _buildDropdownSetting(
                        label: 'Lesson Reminder Time',
                        description: 'When to send lesson reminders to students',
                        value: _reminderHoursBefore,
                        items: reminderHoursOptions
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(h == 1 ? '1 hour before' : '$h hours before'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _reminderHoursBefore = value);
                          }
                        },
                      ),
                      const Divider(height: 32),
                      SwitchListTile(
                        title: const Text('Auto-send "On Way"'),
                        subtitle: const Text('Automatically notify student when you open navigation'),
                        value: _autoSendOnWay,
                        onChanged: (value) => setState(() => _autoSendOnWay = value),
                      ),
                      const Divider(height: 32),
                      SwitchListTile(
                        title: const Text('Auto-send "Arrived"'),
                        subtitle: const Text('Automatically notify student when you arrive'),
                        value: _autoSendArrived,
                        onChanged: (value) => setState(() => _autoSendArrived = value),
                      ),
                      const Divider(height: 32),
                      // Feature 2.5: Low balance alerts
                      SwitchListTile(
                        title: const Text('Low Balance Alerts'),
                        subtitle: const Text('Get notified when a student\'s balance is low'),
                        value: _lowBalanceAlertEnabled,
                        onChanged: (value) => setState(() => _lowBalanceAlertEnabled = value),
                      ),
                      if (_lowBalanceAlertEnabled) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alert when balance drops below ${_lowBalanceThresholdHours.toStringAsFixed(1)} hours',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Slider(
                                value: _lowBalanceThresholdHours,
                                min: 0.5,
                                max: 10.0,
                                divisions: 19,
                                label: '${_lowBalanceThresholdHours.toStringAsFixed(1)} hrs',
                                onChanged: (value) {
                                  setState(() => _lowBalanceThresholdHours = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoNote(
                    'Students will receive a push notification $_reminderHoursBefore ${_reminderHoursBefore == 1 ? 'hour' : 'hours'} before their lesson.',
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveSettings,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
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
      ],
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDropdownSetting<T>({
    required String label,
    required String description,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurface,
            ),
            dropdownColor: colorScheme.surfaceContainerHigh,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
