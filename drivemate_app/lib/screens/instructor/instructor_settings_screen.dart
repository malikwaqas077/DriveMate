import 'package:flutter/material.dart';

import '../../models/cancellation_rule.dart';
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

  // Cancellation rules
  late List<CancellationRule> _cancellationRules;
  late int _reminderHoursBefore;
  
  // Notification settings
  late bool _autoSendOnWay;
  late bool _autoSendArrived;
  
  // Navigation settings
  late String? _defaultNavigationApp;

  // Options
  static const List<int> reminderHoursOptions = [1, 2, 6, 12, 24];
  static const List<int> chargePercentOptions = [0, 25, 50, 75, 100];
  static const List<int> hoursBeforeOptions = [12, 24, 48, 72, 96, 120];
  static const List<Map<String, String>> navigationApps = [
    {'value': 'system', 'label': 'System Default'},
    {'value': 'google_maps', 'label': 'Google Maps'},
    {'value': 'apple_maps', 'label': 'Apple Maps'},
  ];

  @override
  void initState() {
    super.initState();
    final settings = widget.instructor.instructorSettings;
    
    // Get cancellation rules (from new settings or legacy)
    _cancellationRules = widget.instructor.getCancellationRules();
    if (_cancellationRules.isEmpty) {
      _cancellationRules = [
        CancellationRule(hoursBefore: 24, chargePercent: 100),
        CancellationRule(hoursBefore: 48, chargePercent: 50),
        CancellationRule(hoursBefore: 72, chargePercent: 0),
      ];
    }
    
    _reminderHoursBefore = widget.instructor.getReminderHours();
    if (!reminderHoursOptions.contains(_reminderHoursBefore)) {
      _reminderHoursBefore = 24;
    }
    
    // Notification settings
    _autoSendOnWay = settings?.notificationSettings?['autoSendOnWay'] ?? false;
    _autoSendArrived = settings?.notificationSettings?['autoSendArrived'] ?? false;
    
    // Navigation settings
    _defaultNavigationApp = settings?.defaultNavigationApp ?? 'system';
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      // Sort rules by hoursBefore (descending)
      _cancellationRules.sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));
      
      final settings = InstructorSettings(
        cancellationRules: _cancellationRules,
        reminderHoursBefore: _reminderHoursBefore,
        notificationSettings: {
          'autoSendOnWay': _autoSendOnWay,
          'autoSendArrived': _autoSendArrived,
        },
        defaultNavigationApp: _defaultNavigationApp == 'system' ? null : _defaultNavigationApp,
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

  void _addCancellationRule() {
    setState(() {
      _cancellationRules.add(CancellationRule(hoursBefore: 24, chargePercent: 50));
    });
  }

  void _removeCancellationRule(int index) {
    setState(() {
      _cancellationRules.removeAt(index);
    });
  }

  void _updateCancellationRule(int index, CancellationRule rule) {
    setState(() {
      _cancellationRules[index] = rule;
    });
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
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCancellationRulesSection(),
                  const SizedBox(height: 32),
                  _buildReminderSection(),
                  const SizedBox(height: 32),
                  _buildNotificationSection(),
                  const SizedBox(height: 32),
                  _buildNavigationSection(),
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

  Widget _buildCancellationRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Cancellation Rules',
          subtitle: 'Configure charges based on cancellation timing',
          icon: Icons.event_busy_rounded,
          iconColor: AppTheme.warning,
          iconBgColor: AppTheme.warningLight,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rules',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutral900,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addCancellationRule,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Rule'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_cancellationRules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No cancellation rules. Add a rule to configure charges.',
                    style: TextStyle(color: AppTheme.neutral500),
                  ),
                )
              else
                ...List.generate(_cancellationRules.length, (index) {
                  final rule = _cancellationRules[index];
                  return _buildCancellationRuleItem(index, rule);
                }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoNote(
          'Rules are evaluated from highest to lowest hours. The first matching rule applies.',
        ),
      ],
    );
  }

  Widget _buildCancellationRuleItem(int index, CancellationRule rule) {
    return Container(
      margin: EdgeInsets.only(bottom: index < _cancellationRules.length - 1 ? 16 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: rule.hoursBefore,
                  decoration: const InputDecoration(
                    labelText: 'Hours Before',
                    isDense: true,
                  ),
                  items: hoursBeforeOptions.map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text('$h hours'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateCancellationRule(
                        index,
                        rule.copyWith(hoursBefore: value),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: rule.chargePercent,
                  decoration: const InputDecoration(
                    labelText: 'Charge %',
                    isDense: true,
                  ),
                  items: chargePercentOptions.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text('$p%'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateCancellationRule(
                        index,
                        rule.copyWith(chargePercent: value),
                      );
                    }
                  },
                ),
              ),
              if (_cancellationRules.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () => _removeCancellationRule(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If cancelled ${rule.hoursBefore}h or less before lesson: Charge ${rule.chargePercent}%',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Notification Settings',
          subtitle: 'Configure automatic notifications when navigating',
          icon: Icons.notifications_outlined,
          iconColor: AppTheme.primary,
          iconBgColor: AppTheme.primary.withOpacity(0.1),
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          children: [
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
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Navigation',
          subtitle: 'Choose your default navigation app',
          icon: Icons.navigation_rounded,
          iconColor: AppTheme.secondary,
          iconBgColor: AppTheme.secondaryLight,
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          children: [
            _buildDropdownSetting(
              label: 'Default Navigation App',
              description: 'Which app to use when navigating to students',
              value: _defaultNavigationApp ?? 'system',
              items: navigationApps.map((app) {
                return DropdownMenuItem(
                  value: app['value'],
                  child: Text(app['label']!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _defaultNavigationApp = value);
                }
              },
            ),
          ],
        ),
      ],
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
