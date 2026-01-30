import 'package:flutter/material.dart';

import '../services/theme_service.dart';

/// App-wide appearance settings: Light, Dark, or follow device (System).
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = ThemeService.instance.themeMode;
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _selected = mode);
    await ThemeService.instance.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _OptionCard(
            icon: Icons.brightness_auto_rounded,
            label: 'System default',
            subtitle: 'Follow device light/dark setting',
            selected: _selected == ThemeMode.system,
            onTap: () => _setTheme(ThemeMode.system),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            subtitle: 'Always use light theme',
            selected: _selected == ThemeMode.light,
            onTap: () => _setTheme(ThemeMode.light),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            subtitle: 'Always use dark theme',
            selected: _selected == ThemeMode.dark,
            onTap: () => _setTheme(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = selected
        ? colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1)
        : colorScheme.surfaceContainerHighest;
    final iconColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
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
                    label,
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
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
