import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class InstructorSettingsScreen extends StatefulWidget {
  const InstructorSettingsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<InstructorSettingsScreen> createState() =>
      _InstructorSettingsScreenState();
}

class _InstructorSettingsScreenState extends State<InstructorSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _saving = false;

  // Cancellation policy settings
  late int _windowHours;
  late int _chargePercent;
  late int _reminderHoursBefore;

  // Options for dropdowns
  static const List<int> windowHoursOptions = [12, 24, 48, 72];
  static const List<int> chargePercentOptions = [25, 50, 75, 100];
  static const List<int> reminderHoursOptions = [1, 2, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    final policy = widget.instructor.cancellationPolicy;
    _windowHours = policy?.windowHours ?? 24;
    _chargePercent = policy?.chargePercent ?? 50;
    _reminderHoursBefore = widget.instructor.reminderHoursBefore ?? 24;

    // Ensure values are in the allowed options
    if (!windowHoursOptions.contains(_windowHours)) {
      _windowHours = 24;
    }
    if (!chargePercentOptions.contains(_chargePercent)) {
      _chargePercent = 50;
    }
    if (!reminderHoursOptions.contains(_reminderHoursBefore)) {
      _reminderHoursBefore = 24;
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      await _firestoreService.updateUserProfile(widget.instructor.id, {
        'cancellationPolicy': {
          'windowHours': _windowHours,
          'chargePercent': _chargePercent,
        },
        'reminderHoursBefore': _reminderHoursBefore,
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
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.neutral700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Cancellation Policy',
              subtitle: 'Configure how cancellations are handled',
              icon: Icons.event_busy_rounded,
              iconColor: AppTheme.warning,
              iconBgColor: AppTheme.warningLight,
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              children: [
                _buildDropdownSetting(
                  label: 'Cancellation window',
                  description: 'Minimum hours before lesson start for free cancellation',
                  value: _windowHours,
                  items: windowHoursOptions
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text('$h hours'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _windowHours = value);
                    }
                  },
                ),
                const Divider(height: 32),
                _buildDropdownSetting(
                  label: 'Late cancellation charge',
                  description: 'Percentage of lesson hours charged for late cancellation',
                  value: _chargePercent,
                  items: chargePercentOptions
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('$p%'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _chargePercent = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoNote(
              'Students cancelling within $_windowHours hours of the lesson will be charged $_chargePercent% of the lesson hours.',
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              title: 'Lesson Reminders',
              subtitle: 'Configure automatic student notifications',
              icon: Icons.notifications_active_rounded,
              iconColor: AppTheme.info,
              iconBgColor: AppTheme.infoLight,
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              children: [
                _buildDropdownSetting(
                  label: 'Reminder time',
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
              ],
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.neutral500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.neutral500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.neutral100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.neutral900,
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
