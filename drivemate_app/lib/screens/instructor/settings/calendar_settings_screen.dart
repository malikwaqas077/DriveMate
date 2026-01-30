import 'package:flutter/material.dart';

import '../../../models/user_profile.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';

class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _saving = false;

  late Map<String, Color> _lessonColors;
  late String _defaultCalendarView;

  static const Map<String, Color> defaultLessonColors = {
    'lesson': Colors.orange,
    'test': Colors.blue,
    'mock_test': Colors.deepPurple,
  };

  @override
  void initState() {
    super.initState();
    final settings = widget.instructor.instructorSettings;
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
    _defaultCalendarView = settings?.defaultCalendarView ?? 'grid';
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      final currentSettings = widget.instructor.instructorSettings;
      final settings = InstructorSettings(
        cancellationRules: currentSettings?.cancellationRules,
        reminderHoursBefore: currentSettings?.reminderHoursBefore,
        notificationSettings: currentSettings?.notificationSettings,
        defaultNavigationApp: currentSettings?.defaultNavigationApp,
        lessonColors: {
          'lesson': _lessonColors['lesson']!.value,
          'test': _lessonColors['test']!.value,
          'mock_test': _lessonColors['mock_test']!.value,
        },
        defaultCalendarView: _defaultCalendarView,
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
          'Calendar Settings',
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
                    title: 'Calendar Settings',
                    subtitle: 'Customize calendar view and colors',
                    icon: Icons.calendar_today_outlined,
                    iconColor: AppTheme.secondary,
                    iconBgColor: AppTheme.secondaryLight,
                  ),
                  const SizedBox(height: 24),
                  // Default View Setting
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
                        Text(
                          'Default View',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose your preferred calendar view',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ToggleButtons(
                          isSelected: [
                            _defaultCalendarView == 'grid',
                            _defaultCalendarView == 'list',
                          ],
                          onPressed: (index) {
                            setState(() {
                              _defaultCalendarView = index == 0 ? 'grid' : 'list';
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            minWidth: 100,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.grid_view, size: 20),
                                  SizedBox(width: 8),
                                  Text('Grid'),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.view_list, size: 20),
                                  SizedBox(width: 8),
                                  Text('List'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Lesson Colors Section
                  _buildSectionHeader(
                    context,
                    title: 'Lesson Colors',
                    subtitle: 'Customize colors for each lesson type',
                    icon: Icons.palette_outlined,
                    iconColor: AppTheme.secondary,
                    iconBgColor: AppTheme.secondaryLight,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _buildColorPickerItem(
                          context,
                          label: 'Driving Lesson',
                          lessonType: 'lesson',
                          color: _lessonColors['lesson']!,
                        ),
                        const Divider(height: 32),
                        _buildColorPickerItem(
                          context,
                          label: 'Driving Test',
                          lessonType: 'test',
                          color: _lessonColors['test']!,
                        ),
                        const Divider(height: 32),
                        _buildColorPickerItem(
                          context,
                          label: 'Mock Test',
                          lessonType: 'mock_test',
                          color: _lessonColors['mock_test']!,
                        ),
                      ],
                    ),
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

  Widget _buildColorPickerItem(
    BuildContext context, {
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
}

// Color picker dialog
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
