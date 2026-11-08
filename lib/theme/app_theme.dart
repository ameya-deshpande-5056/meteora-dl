import 'package:flutter/material.dart';
import 'app_shapes.dart';
import 'app_typography.dart';

enum AppThemeMode {
  system('Follow System'),
  light('Light Mode'),
  dark('Dark Mode'),
  amoled('AMOLED Black');

  final String label;
  const AppThemeMode(this.label);
}

class AppTheme {
  // Primary brand seed color (Deep Tech Azure)
  static const Color seedColor = Color(0xFF007A99);

  /// Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
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
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: AppShapes.cardShape,
        color: colorScheme.surfaceContainerLow,
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
    );
  }

  /// Dark Theme (Slate/Charcoal)
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF10141A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),
      scaffoldBackgroundColor: const Color(0xFF10141A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF10141A),
        foregroundColor: Color(0xFFE1E2E8),
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: AppShapes.cardShape,
        color: const Color(0xFF171D25),
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
        backgroundColor: const Color(0xFF171D25),
        elevation: 2,
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }

  /// AMOLED Pure Black Theme (0x000000 surface for maximum OLED battery savings)
  static ThemeData get amoledTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: Colors.black,
    ).copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0D0F12),
      surfaceContainer: const Color(0xFF14171D),
      surfaceContainerHigh: const Color(0xFF1B2028),
      surfaceContainerHighest: const Color(0xFF232934),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: AppShapes.cardShape,
        color: const Color(0xFF12151B),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
    );
  }
}
