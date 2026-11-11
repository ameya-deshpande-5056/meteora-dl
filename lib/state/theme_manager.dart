import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import '../theme/app_theme.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal();

  static const _settingsKey = 'theme_mode';
  MeteoraDatabase? _database;
  AppThemeMode _currentMode = AppThemeMode.system;

  AppThemeMode get currentMode => _currentMode;

  void init(MeteoraDatabase? database) {
    _database = database;
    final saved = database?.getSetting(_settingsKey);
    if (saved != null) {
      final restored = AppThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => AppThemeMode.system,
      );
      if (restored != _currentMode) {
        _currentMode = restored;
        notifyListeners();
      }
    }
  }

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

  ThemeData resolveLightTheme({ColorScheme? dynamicScheme}) {
    return AppTheme.buildLightTheme(dynamicScheme: dynamicScheme);
  }

  ThemeData resolveDarkTheme({ColorScheme? dynamicScheme}) {
    return AppTheme.buildDarkTheme(
      dynamicScheme: dynamicScheme,
      amoled: _currentMode == AppThemeMode.amoled,
    );
  }

  ThemeData get activeDarkTheme {
    return resolveDarkTheme();
  }

  void setThemeMode(AppThemeMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _database?.setSetting(_settingsKey, mode.name);
      notifyListeners();
    }
  }
}
