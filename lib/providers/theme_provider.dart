import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = const AppTheme(AppThemeMode.cosmos);

  AppTheme get currentTheme => _currentTheme;
  AppThemeMode get currentMode => _currentTheme.mode;

  ThemeProvider() {
    _load();
  }

  void _load() {
    try {
      final box   = Hive.box('settings');
      final saved = box.get('theme', defaultValue: 'cosmos') as String;
      final mode  = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.cosmos,
      );
      _currentTheme = AppTheme(mode);
    } catch (_) {
      _currentTheme = const AppTheme(AppThemeMode.cosmos);
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_currentTheme.mode == mode) return;
    _currentTheme = AppTheme(mode);
    notifyListeners();
    // Save asynchronously — UI block nahi hoga
    try {
      await Hive.box('settings').put('theme', mode.name);
    } catch (_) {}
  }

  List<AppTheme> get allThemes =>
      AppThemeMode.values.map((m) => AppTheme(m)).toList();

  bool isActive(AppThemeMode mode) => _currentTheme.mode == mode;
}