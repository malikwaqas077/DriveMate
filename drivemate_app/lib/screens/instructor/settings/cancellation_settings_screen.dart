import 'package:flutter/material.dart';

import '../../../models/cancellation_rule.dart';
import '../../../models/user_profile.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';

class CancellationSettingsScreen extends StatefulWidget {
  const CancellationSettingsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<CancellationSettingsScreen> createState() =>
      _CancellationSettingsScreenState();
}

class _CancellationSettingsScreenState extends State<CancellationSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _saving = false;

  late List<CancellationRule> _cancellationRules;

  static const List<int> chargePercentOptions = [0, 25, 50, 75, 100];
  static const List<int> hoursBeforeOptions = [12, 24, 48, 72, 96, 120];

  @override
  void initState() {
    super.initState();
    _cancellationRules = widget.instructor.getCancellationRules();
    if (_cancellationRules.isEmpty) {
      _cancellationRules = [
        CancellationRule(hoursBefore: 24, chargePercent: 100),
        CancellationRule(hoursBefore: 48, chargePercent: 50),
        CancellationRule(hoursBefore: 72, chargePercent: 0),
      ];
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      _cancellationRules.sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));

      final currentSettings = widget.instructor.instructorSettings;
      final settings = InstructorSettings(
        cancellationRules: _cancellationRules,
        reminderHoursBefore: currentSettings?.reminderHoursBefore,
        notificationSettings: currentSettings?.notificationSettings,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Cancellations',
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
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    title: 'Cancellations',
                    subtitle: 'Configure charges based on cancellation timing',
                    icon: Icons.event_busy_rounded,
                    iconColor: AppTheme.warning,
                    iconBgColor: AppTheme.warningLight,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rules',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
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
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No cancellation rules. Add a rule to configure charges.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          )
                        else
                          ...List.generate(_cancellationRules.length, (index) {
                            final rule = _cancellationRules[index];
                            return _buildCancellationRuleItem(context, index, rule);
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoNote(
                    'Rules are evaluated from highest to lowest hours. The first matching rule applies.',
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
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
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

  Widget _buildCancellationRuleItem(BuildContext context, int index, CancellationRule rule) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: index < _cancellationRules.length - 1 ? 16 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
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
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
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
