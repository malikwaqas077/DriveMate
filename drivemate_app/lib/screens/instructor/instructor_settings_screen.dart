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
  
  // Lesson colors
  late Map<String, Color> _lessonColors;

  // Options
  static const List<int> reminderHoursOptions = [1, 2, 6, 12, 24];
  static const List<int> chargePercentOptions = [0, 25, 50, 75, 100];
  static const List<int> hoursBeforeOptions = [12, 24, 48, 72, 96, 120];
  static const List<Map<String, String>> navigationApps = [
    {'value': 'system', 'label': 'System Default'},
    {'value': 'google_maps', 'label': 'Google Maps'},
    {'value': 'apple_maps', 'label': 'Apple Maps'},
  ];
  
  // Default lesson colors
  static const Map<String, Color> defaultLessonColors = {
    'lesson': Colors.orange,
    'test': Colors.blue,
    'mock_test': Colors.deepPurple,
  };

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
    
    // Lesson colors
    final savedColors = settings?.lessonColors;
    _lessonColors = {
      'lesson': savedColors?['lesson'] != null
          ? Color(savedColors!['lesson']!)
          : defaultLessonColors['lesson']!,
      'test': (savedColors?['test'] != null)
          ? Color(savedColors!['test']!)
          : defaultLessonColors['test']!,
      'mock_test': (savedColors?['mock_test'] != null)
          ? Color(savedColors!['mock_test']!)
          : defaultLessonColors['mock_test']!,
    };
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
        lessonColors: {
          'lesson': _lessonColors['lesson']!.value,
          'test': _lessonColors['test']!.value,
          'mock_test': _lessonColors['mock_test']!.value,
        },
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
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationSection(),
                  const SizedBox(height: 32),
                  _buildCancellationRulesSection(),
                  const SizedBox(height: 32),
                  _buildCalendarColorsSection(),
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
          title: 'Cancellations',
          subtitle: 'Configure charges based on cancellation timing',
          icon: Icons.event_busy_rounded,
          iconColor: AppTheme.warning,
          iconBgColor: AppTheme.warningLight,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Notifications',
          subtitle: 'Configure automatic notifications and reminders',
          icon: Icons.notifications_outlined,
          iconColor: AppTheme.primary,
          iconBgColor: AppTheme.primary.withOpacity(0.1),
        ),
        const SizedBox(height: 16),
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
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoNote(
          'Students will receive a push notification $_reminderHoursBefore ${_reminderHoursBefore == 1 ? 'hour' : 'hours'} before their lesson.',
        ),
      ],
    );
  }

  Widget _buildCalendarColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Calendar Colors',
          subtitle: 'Customize colors for each lesson type',
          icon: Icons.palette_outlined,
          iconColor: AppTheme.secondary,
          iconBgColor: AppTheme.secondaryLight,
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          children: [
            _buildColorPickerItem(
              label: 'Driving Lesson',
              lessonType: 'lesson',
              color: _lessonColors['lesson']!,
            ),
            const Divider(height: 32),
            _buildColorPickerItem(
              label: 'Driving Test',
              lessonType: 'test',
              color: _lessonColors['test']!,
            ),
            const Divider(height: 32),
            _buildColorPickerItem(
              label: 'Mock Test',
              lessonType: 'mock_test',
              color: _lessonColors['mock_test']!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPickerItem({
    required String label,
    required String lessonType,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showColorPicker(lessonType, color),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 2),
                  Text(
                    '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(String lessonType, Color currentColor) async {
    final Color? pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        currentColor: currentColor,
        lessonType: lessonType,
      ),
    );
    
    if (pickedColor != null) {
      setState(() {
        _lessonColors[lessonType] = pickedColor;
      });
    }
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
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
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

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.currentColor,
    required this.lessonType,
  });

  final Color currentColor;
  final String lessonType;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  // Predefined color palette
  static const List<Color> _colorPalette = [
    Colors.orange,
    Colors.blue,
    Colors.deepPurple,
    Colors.green,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
    Colors.blueGrey,
    Colors.deepOrange,
    Colors.purple,
    Colors.lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Choose Color for ${_getLessonTypeLabel(widget.lessonType)}'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current color preview
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.neutral300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: _getContrastColor(_selectedColor),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Color palette grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorPalette.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.neutral300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Custom color picker button
            OutlinedButton.icon(
              onPressed: () async {
                final Color? picked = await showDialog<Color>(
                  context: context,
                  builder: (context) => _FullColorPickerDialog(
                    currentColor: _selectedColor,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedColor = picked);
                }
              },
              icon: const Icon(Icons.colorize),
              label: const Text('Custom Color'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getLessonTypeLabel(String lessonType) {
    switch (lessonType) {
      case 'test':
        return 'Driving Test';
      case 'mock_test':
        return 'Mock Test';
      default:
        return 'Driving Lesson';
    }
  }

  Color _getContrastColor(Color color) {
    // Calculate relative luminance
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _FullColorPickerDialog extends StatefulWidget {
  const _FullColorPickerDialog({required this.currentColor});

  final Color currentColor;

  @override
  State<_FullColorPickerDialog> createState() => _FullColorPickerDialogState();
}

class _FullColorPickerDialogState extends State<_FullColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Color'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color preview
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neutral300, width: 2),
              ),
            ),
            const SizedBox(height: 24),
            // Hue slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hue'),
                Slider(
                  value: _hue,
                  min: 0,
                  max: 360,
                  onChanged: (value) => setState(() => _hue = value),
                ),
              ],
            ),
            // Saturation slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saturation'),
                Slider(
                  value: _saturation,
                  min: 0,
                  max: 1,
                  onChanged: (value) => setState(() => _saturation = value),
                ),
              ],
            ),
            // Value/Brightness slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Brightness'),
                Slider(
                  value: _value,
                  min: 0,
                  max: 1,
                  onChanged: (value) => setState(() => _value = value),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
