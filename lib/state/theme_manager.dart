import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal();

  AppThemeMode _currentMode = AppThemeMode.dark;

  AppThemeMode get currentMode => _currentMode;

  ThemeMode get flutterThemeMode {
    switch (_currentMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
    }
  }

  ThemeData get activeDarkTheme {
    return _currentMode == AppThemeMode.amoled ? AppTheme.amoledTheme : AppTheme.darkTheme;
  }

  void setThemeMode(AppThemeMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }
}
