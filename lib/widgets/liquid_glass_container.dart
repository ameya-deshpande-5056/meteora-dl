import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_shapes.dart';

/// Visual weight of a Liquid Glass surface.
enum LiquidGlassStyle {
  /// Default frosted glass: strong blur, soft tint, bright specular rim.
  regular,

  /// Clearer glass for surfaces layered over rich content such as thumbnails.
  clear,
}

/// An iOS-style Liquid Glass surface.
///
/// Layers, from back to front:
/// 1. a real-time [BackdropFilter] blur of the content behind the surface,
/// 2. a directional vibrancy gradient (specular sheen at the top-left, tint of
///    the active [ColorScheme.primary] at the bottom-right),
/// 3. a soft top-edge gloss pass,
/// 4. a two-tone specular rim plus an inset highlight stroke, painted by
///    [_SpecularGlassBorderPainter],
/// 5. an ambient drop shadow with a coloured inner glow in dark themes.
///
/// When the platform requests reduced motion (or [enableBlur] is false) the
/// surface degrades to an opaque tinted card so text contrast never depends on
/// the blur.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final bool enableBlur;
  final bool showShadow;
  final VoidCallback? onTap;

  /// Optional accent used by the bottom-right vibrancy tint.
  final Color? tint;
  final LiquidGlassStyle style;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppShapes.large,
    this.blurSigma = 18.0,
    // Blur is opt-in: a full-screen-ish BackdropFilter per card is the single
    // biggest source of jank. Only chrome that floats over moving content
    // (dock, app bar, sheets, dialogs) should enable it.
    this.enableBlur = false,
    this.showShadow = true,
    this.onTap,
    this.tint,
    this.style = LiquidGlassStyle.regular,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final useBlur = enableBlur && !reduceMotion;
    final isClear = style == LiquidGlassStyle.clear;
    final radius = BorderRadius.circular(borderRadius);
    final accent = tint ?? colorScheme.primary;

    // Directional vibrancy: bright sheen top-left, accent tint bottom-right.
    final topSheen = Color.alphaBlend(
      Colors.white.withAlpha(useBlur ? (isDark ? (isClear ? 20 : 34) : (isClear ? 96 : 168)) : (isDark ? 46 : 236)),
      colorScheme.surfaceContainerHigh.withAlpha(useBlur ? (isDark ? (isClear ? 92 : 126) : (isClear ? 96 : 128)) : 250),
    );
    final bottomTint = Color.alphaBlend(
      accent.withAlpha(useBlur ? (isDark ? 20 : 14) : (isDark ? 26 : 18)),
      colorScheme.surfaceContainer.withAlpha(useBlur ? (isDark ? (isClear ? 86 : 112) : 118) : 250),
    );

    // Rim: crisp light catch on the lit edge, soft falloff on the far edge.
    final rimTop = isDark
        ? Colors.white.withAlpha(isClear ? 92 : 116)
        : Colors.white.withAlpha(isClear ? 180 : 238);
    final rimBottom = isDark
        ? Colors.white.withAlpha(isClear ? 18 : 28)
        : colorScheme.outlineVariant.withAlpha(96);
    final insetGlow = isDark
        ? accent.withAlpha(22)
        : Colors.white.withAlpha(150);

    Widget surface = CustomPaint(
      foregroundPainter: _SpecularGlassBorderPainter(
        borderRadius: borderRadius,
        topLeftColor: rimTop,
        bottomRightColor: rimBottom,
        insetGlowColor: insetGlow,
        glossColor: Colors.white.withAlpha(useBlur ? (isDark ? 22 : 46) : (isDark ? 14 : 22)),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topSheen, bottomTint],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: child,
        ),
      ),
    );

    if (useBlur) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(borderRadius: radius, child: surface);
    }

    if (onTap != null) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashFactory: InkSparkle.splashFactory,
          child: surface,
        ),
      );
    }

    if (showShadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? (isClear ? 70 : 100) : 22),
              blurRadius: 26,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
            if (isDark)
              BoxShadow(
                color: accent.withAlpha(16),
                blurRadius: 22,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: surface,
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    return RepaintBoundary(child: surface);
  }
}

/// Paints the specular rim, the inset highlight stroke and a top-edge gloss.
class _SpecularGlassBorderPainter extends CustomPainter {
  final double borderRadius;
  final Color topLeftColor;
  final Color bottomRightColor;
  final Color insetGlowColor;
  final Color glossColor;

  const _SpecularGlassBorderPainter({
    required this.borderRadius,
    required this.topLeftColor,
    required this.bottomRightColor,
    required this.insetGlowColor,
    required this.glossColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(borderRadius),
    );

    // 1. Specular rim.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
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
    canvas.drawRRect(outer, rimPaint);

    // 2. Inset highlight, one pixel inside the rim.
    final inset = RRect.fromRectAndRadius(
      rect.deflate(2.4),
      Radius.circular(borderRadius - 2.4 < 0 ? 0 : borderRadius - 2.4),
    );
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [insetGlowColor, Colors.transparent],
      ).createShader(rect);
    canvas.drawRRect(inset, insetPaint);

    // 3. Top-edge gloss band, clipped to the rounded shape.
    canvas.save();
    canvas.clipRRect(outer);
    final glossRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glossColor, Colors.transparent],
      ).createShader(glossRect);
    canvas.drawRect(glossRect, glossPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpecularGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.topLeftColor != topLeftColor ||
        oldDelegate.bottomRightColor != bottomRightColor ||
        oldDelegate.insetGlowColor != insetGlowColor ||
        oldDelegate.glossColor != glossColor;
  }
}

/// Ambient lighting behind Liquid Glass surfaces.
///
/// Three soft radial blooms plus a vertical shade give the blur something to
/// refract, without running any animation (so it costs a single paint pass).
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && theme.scaffoldBackgroundColor == Colors.black;
    final scale = isAmoled ? 0.7 : 1.0;

    final primaryGlow = colorScheme.primary.withAlpha((isDark ? 40 : 30) * scale ~/ 1);
    final secondaryGlow = colorScheme.secondary.withAlpha((isDark ? 26 : 22) * scale ~/ 1);
    final tertiaryGlow = colorScheme.tertiary.withAlpha((isDark ? 30 : 22) * scale ~/ 1);

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colorScheme.surfaceContainerLowest.withAlpha(isDark ? 90 : 40),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.9),
                  radius: 1.1,
                  colors: [primaryGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, 0.2),
                  radius: 1.0,
                  colors: [secondaryGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, 0.95),
                  radius: 1.05,
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

/// Translucent Liquid Glass app bar that frosts over scrolling content.
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
        ? theme.scaffoldBackgroundColor.withAlpha(reduceMotion ? 244 : 150)
        : colorScheme.surface.withAlpha(reduceMotion ? 248 : 170);

    final bottomEdgeColor = isDark
        ? Colors.white.withAlpha(28)
        : colorScheme.outlineVariant.withAlpha(90);

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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barBg,
            Color.alphaBlend(
              colorScheme.primary.withAlpha(isDark ? 10 : 6),
              barBg,
            ),
          ],
        ),
        border: Border(bottom: BorderSide(color: bottomEdgeColor, width: 0.8)),
      ),
      child: appBar,
    );

    if (reduceMotion) return decorated;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: decorated,
      ),
    );
  }
}
