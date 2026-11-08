import 'package:flutter/material.dart';

class LiquidGlassTheme {
  static const Color background = Color(0xFF090C12);
  static const Color surface = Color(0xFF101522);
  static const Color surfaceContainer = Color(0xFF161E2E);
  static const Color surfaceHigh = Color(0xFF1E283E);

  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x24FFFFFF);
  static const Color glassBorderHighlight = Color(0x4000D2FF);

  static const Color cyanAccent = Color(0xFF00D2FF);
  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color amberAccent = Color(0xFFF59E0B);
  static const Color roseAccent = Color(0xFFF43F5E);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: cyanAccent,
        secondary: indigoAccent,
        tertiary: emeraldAccent,
        error: roseAccent,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xDD090C12),
        indicatorColor: cyanAccent.withAlpha(51),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: cyanAccent, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: cyanAccent, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
      ),
    );
  }
}
