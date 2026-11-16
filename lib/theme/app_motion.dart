import 'package:flutter/material.dart';

/// Material 3 Expressive motion tokens.
///
/// Expressive surfaces are springy rather than linear: short durations with
/// overshoot on entry and emphasized easing on exit.
class AppMotion {
  const AppMotion._();

  /// Quick state change (chip selection, icon swap).
  static const Duration fast = Duration(milliseconds: 180);

  /// Standard expressive transition (cards, sheets, indicators).
  static const Duration medium = Duration(milliseconds: 320);

  /// Larger surface transition (page-level, dialog entry).
  static const Duration slow = Duration(milliseconds: 480);

  /// One full cycle of an indeterminate wavy progress indicator.
  static const Duration progressCycle = Duration(milliseconds: 1600);

  /// Overshoots slightly — used for selection indicators and pills.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Material 3 "emphasized" decelerate curve.
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 "emphasized" accelerate curve for exits.
  static const Curve emphasizedExit = Cubic(0.3, 0.0, 0.8, 0.15);

  static const Curve standard = Curves.easeOutCubic;

  /// Returns a duration scaled to zero when the platform requests reduced motion.
  static Duration respectReducedMotion(BuildContext context, Duration duration) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
  }
}
