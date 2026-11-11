import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_shapes.dart';
import 'app_typography.dart';

enum AppThemeMode {
  system('Follow System', 'Match device appearance'),
  light('Light Mode', 'Clean bright appearance'),
  dark('Dark Mode', 'Low-light dark theme'),
  amoled('AMOLED Black', 'Pure black for OLED displays');

  final String label;
  final String description;
  const AppThemeMode(this.label, this.description);
}

class AppTheme {
  // Primary brand seed color fallback (Deep Tech Azure)
  static const Color seedColor = Color(0xFF007A99);

  /// Builds the light theme using Android 12+ wallpaper dynamic color if available,
  /// falling back to the brand seed color.
  static ThemeData buildLightTheme({ColorScheme? dynamicScheme}) {
    final colorScheme = dynamicScheme ?? ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(90),
            width: 0.8,
          ),
        ),
        color: colorScheme.surfaceContainerLow.withAlpha(215),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 2,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          ),
        ),
      ),
    );
  }

  /// Builds the dark theme using Android 12+ wallpaper dynamic color if available,
  /// falling back to the brand seed color. When [amoled] is true, enforces pure black surfaces.
  static ThemeData buildDarkTheme({ColorScheme? dynamicScheme, bool amoled = false}) {
    ColorScheme colorScheme = dynamicScheme ?? ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    if (amoled) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF181818),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }

    final surfaceBg = amoled ? Colors.black : colorScheme.surface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),
      scaffoldBackgroundColor: surfaceBg,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: amoled ? 0 : 2,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          side: BorderSide(
            color: Colors.white.withAlpha(amoled ? 30 : 24),
            width: 0.8,
          ),
        ),
        color: amoled
            ? const Color(0xD90E0E0E)
            : colorScheme.surfaceContainerLow.withAlpha(205),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: amoled ? Colors.black : colorScheme.surfaceContainer,
        elevation: amoled ? 0 : 2,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.large)),
          ),
        ),
      ),
    );
  }

  // Legacy static getters for tests
  static ThemeData get lightTheme => buildLightTheme();
  static ThemeData get darkTheme => buildDarkTheme();
  static ThemeData get amoledTheme => buildDarkTheme(amoled: true);
}
