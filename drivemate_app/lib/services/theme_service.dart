import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes app theme mode (light / dark / system).
/// System follows the device setting.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const _keyThemeMode = 'theme_mode';

  final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  ThemeMode get themeMode => notifier.value;

  bool _loaded = false;

  /// Load saved preference and apply. Call once before runApp (e.g. from main).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyThemeMode);
    final mode = _themeModeFromString(stored);
    notifier.value = mode;
    _loaded = true;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToString(mode));
    notifier.value = mode;
  }

  static String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  static ThemeMode _themeModeFromString(String? s) {
    return switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
