import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_shapes.dart';

/// A restrained Liquid Glass container used specifically for floating surfaces:
/// - Floating navigation bars
/// - Search / URL input surfaces
/// - Dialogs & modal bottom sheets
/// - Player overlay controls
///
/// Automatically provides an opaque fallback if reduced motion is requested
/// or when real-time blur is not desired.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool enableBlur;
  final VoidCallback? onTap;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppShapes.large,
    this.enableBlur = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Surface colors
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHigh.withAlpha(enableBlur && !reduceMotion ? 190 : 255)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(enableBlur && !reduceMotion ? 210 : 255);

    final borderColor = theme.colorScheme.outlineVariant.withAlpha(isDark ? 60 : 80);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: child,
    );

    if (enableBlur && !reduceMotion) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }
}
