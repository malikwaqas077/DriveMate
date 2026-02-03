import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes app theme mode (light / dark / system) and theme color.
/// System follows the device setting.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const _keyThemeMode = 'theme_mode';
  static const _keySeedColor = 'theme_seed_color';

  /// Default teal color matching original DriveMate brand
  static const int defaultSeedColor = 0xFF14919B;

  final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<int> seedColorNotifier = ValueNotifier<int>(defaultSeedColor);

  ThemeMode get themeMode => notifier.value;
  int get seedColor => seedColorNotifier.value;

  bool _loaded = false;

  /// Load saved preference and apply. Call once before runApp (e.g. from main).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyThemeMode);
    final mode = _themeModeFromString(stored);
    notifier.value = mode;
    final colorValue = prefs.getInt(_keySeedColor);
    seedColorNotifier.value = colorValue ?? defaultSeedColor;
    _loaded = true;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToString(mode));
    notifier.value = mode;
  }

  Future<void> setSeedColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeedColor, colorValue);
    seedColorNotifier.value = colorValue;
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
