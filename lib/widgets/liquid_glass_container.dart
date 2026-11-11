import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_shapes.dart';

/// A Liquid Glass surface featuring real-time backdrop blur, directional
/// frosted sheen, soft drop shadow, and a specular rim border highlight.
///
/// Automatically falls back to a clean translucent-opaque surface when reduced
/// motion is active or when [enableBlur] is false.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final bool enableBlur;
  final bool showShadow;
  final VoidCallback? onTap;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppShapes.large,
    this.blurSigma = 18.0,
    this.enableBlur = true,
    this.showShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final useBlur = enableBlur && !reduceMotion;

    final topSheenColor = isDark
        ? Color.alphaBlend(
            Colors.white.withAlpha(useBlur ? 28 : 16),
            colorScheme.surfaceContainerHigh.withAlpha(useBlur ? 135 : 238),
          )
        : Color.alphaBlend(
            Colors.white.withAlpha(useBlur ? 140 : 210),
            colorScheme.surfaceContainerHighest.withAlpha(useBlur ? 150 : 242),
          );

    final bottomTintColor = isDark
        ? Color.alphaBlend(
            colorScheme.primary.withAlpha(14),
            colorScheme.surfaceContainer.withAlpha(useBlur ? 120 : 235),
          )
        : Color.alphaBlend(
            colorScheme.primary.withAlpha(10),
            colorScheme.surfaceContainerHigh.withAlpha(useBlur ? 135 : 238),
          );

    final highlightBorderColor = isDark
        ? Colors.white.withAlpha(78)
        : Colors.white.withAlpha(215);

    final shadowBorderColor = isDark
        ? colorScheme.outlineVariant.withAlpha(45)
        : colorScheme.outlineVariant.withAlpha(85);

    final radius = BorderRadius.circular(borderRadius);

    Widget glassBody = CustomPaint(
      foregroundPainter: _SpecularGlassBorderPainter(
        borderRadius: borderRadius,
        topLeftColor: highlightBorderColor,
        bottomRightColor: shadowBorderColor,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topSheenColor, bottomTintColor],
          ),
        ),
        child: child,
      ),
    );

    if (useBlur) {
      glassBody = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: glassBody,
        ),
      );
    } else {
      glassBody = ClipRRect(
        borderRadius: radius,
        child: glassBody,
      );
    }

    if (onTap != null) {
      glassBody = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: glassBody,
        ),
      );
    }

    if (showShadow) {
      glassBody = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 95 : 24),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
            if (isDark)
              BoxShadow(
                color: colorScheme.primary.withAlpha(18),
                blurRadius: 20,
                spreadRadius: -6,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: glassBody,
      );
    }

    if (margin != null) {
      glassBody = Padding(padding: margin!, child: glassBody);
    }

    return glassBody;
  }
}

class _SpecularGlassBorderPainter extends CustomPainter {
  final double borderRadius;
  final Color topLeftColor;
  final Color bottomRightColor;

  const _SpecularGlassBorderPainter({
    required this.borderRadius,
    required this.topLeftColor,
    required this.bottomRightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          topLeftColor,
          Color.lerp(topLeftColor, bottomRightColor, 0.55)!,
          bottomRightColor,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.topLeftColor != topLeftColor ||
        oldDelegate.bottomRightColor != bottomRightColor;
  }
}

/// Provides a subtle ambient lighting canvas behind Liquid Glass surfaces so
/// frosted backdrop blur and specular borders show visible depth.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && theme.scaffoldBackgroundColor == Colors.black;

    final primaryGlow = colorScheme.primary.withAlpha(isAmoled ? 28 : (isDark ? 36 : 26));
    final tertiaryGlow = colorScheme.tertiary.withAlpha(isAmoled ? 20 : (isDark ? 28 : 20));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.85),
                  radius: 1.15,
                  colors: [primaryGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, 0.65),
                  radius: 1.1,
                  colors: [tertiaryGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Translucent Liquid Glass top AppBar that frosts over scrolling content.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final barBg = isDark
        ? theme.scaffoldBackgroundColor.withAlpha(reduceMotion ? 242 : 168)
        : colorScheme.surface.withAlpha(reduceMotion ? 245 : 185);

    final bottomEdgeColor = isDark
        ? Colors.white.withAlpha(24)
        : colorScheme.outlineVariant.withAlpha(80);

    final appBar = AppBar(
      title: title,
      leading: leading,
      actions: actions,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          bottom: BorderSide(color: bottomEdgeColor, width: 0.8),
        ),
      ),
      child: appBar,
    );

    if (reduceMotion) return decorated;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: decorated,
      ),
    );
  }
}
