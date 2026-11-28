import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import 'liquid_glass_container.dart';

/// Destination descriptor for [LiquidGlassNavBar].
class LiquidGlassNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const LiquidGlassNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// An iOS 26 Liquid Glass inspired floating pill navigation bar.
///
/// Performance & fluidity guarantees:
/// - **Single `BackdropFilter`**: only the static outer [LiquidGlassContainer]
///   blurs the backdrop; the sliding liquid lens uses layered specular gradients
///   and a custom rim painter so 60/120 Hz motion never triggers per-frame blur
///   re-rasterization.
/// - **Spring physics + direct scrub**: tapping animates the lens with an
///   underdamped [SpringSimulation], while horizontal dragging tracks the finger
///   continuously with edge rubber-banding, velocity-driven droplet stretch, and
///   haptic ticks across tab boundaries.
/// - **Isolated repaints**: wrapped in a [RepaintBoundary] so lens motion
///   never dirties the underlying screen content.
class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<LiquidGlassNavDestination> destinations;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with TickerProviderStateMixin {
  /// Continuous tab position in `[0.0, destinations.length - 1]`.
  /// Unbounded so spring overshoot and edge rubber-banding work naturally.
  late final AnimationController _lensController;

  /// Controls the subtle "lift & swell" of the liquid droplet while pressed
  /// or actively scrubbed.
  late final AnimationController _swellController;

  /// Tracks horizontal velocity (in tabs/second) for droplet elongation.
  double _dragVelocityTabs = 0.0;
  bool _isDragging = false;
  int _lastHapticIndex = 0;
  double _tabWidth = 1.0;

  static const SpringDescription _lensSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 25.0,
  );

  @override
  void initState() {
    super.initState();
    _lastHapticIndex = widget.currentIndex;
    _lensController = AnimationController.unbounded(
      value: widget.currentIndex.toDouble(),
      vsync: this,
    );
    _swellController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      reverseDuration: AppMotion.normal,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && !_isDragging) {
      _lastHapticIndex = widget.currentIndex;
      _animateToIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _lensController.dispose();
    _swellController.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _animateToIndex(int index, {double initialVelocity = 0.0}) {
    final target = index.toDouble();
    if (_reduceMotion) {
      _lensController.value = target;
      return;
    }
    final simulation = SpringSimulation(
      _lensSpring,
      _lensController.value,
      target,
      initialVelocity,
    );
    _lensController.animateWith(simulation);
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    _lastHapticIndex = index;
    _animateToIndex(index);
    widget.onDestinationSelected(index);
  }

  double _applyRubberBand(double raw, double maxIndex) {
    if (raw < 0.0) {
      return raw * 0.25;
    }
    if (raw > maxIndex) {
      return maxIndex + (raw - maxIndex) * 0.25;
    }
    return raw;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.destinations.length <= 1) return;
    _isDragging = true;
    _dragVelocityTabs = 0.0;
    _lensController.stop();
    if (!_reduceMotion) {
      _swellController.forward();
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _tabWidth <= 0) return;
    final maxIndex = (widget.destinations.length - 1).toDouble();
    final deltaTabs = details.delta.dx / _tabWidth;
    _dragVelocityTabs = (deltaTabs * 60.0).clamp(-12.0, 12.0);

    final nextRaw = _lensController.value + deltaTabs;
    _lensController.value = _applyRubberBand(nextRaw, maxIndex);

    final nearest = _lensController.value.round().clamp(0, widget.destinations.length - 1);
    if (nearest != _lastHapticIndex) {
      _lastHapticIndex = nearest;
      HapticFeedback.selectionClick();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    _dragVelocityTabs = 0.0;
    if (!_reduceMotion) {
      _swellController.reverse();
    }

    final velocityTabs = _tabWidth > 0
        ? (details.velocity.pixelsPerSecond.dx / _tabWidth).clamp(-14.0, 14.0)
        : 0.0;

    // Project slightly forward based on fling velocity so quick flicks
    // naturally advance to the next tab.
    final projected = _lensController.value + velocityTabs * 0.09;
    final target = projected.round().clamp(0, widget.destinations.length - 1);

    _lastHapticIndex = target;
    _animateToIndex(target, initialVelocity: velocityTabs);
    if (target != widget.currentIndex) {
      widget.onDestinationSelected(target);
    }
  }

  void _onHorizontalDragCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    _dragVelocityTabs = 0.0;
    if (!_reduceMotion) {
      _swellController.reverse();
    }
    _animateToIndex(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final count = widget.destinations.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: RepaintBoundary(
          child: LiquidGlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2,
              vertical: 5,
            ),
            borderRadius: AppShapes.full,
            blurSigma: 16,
            enableBlur: true,
            style: LiquidGlassStyle.regular,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = count > 0 ? constraints.maxWidth / count : 0.0;
                _tabWidth = tabWidth;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onHorizontalDragCancel: _onHorizontalDragCancel,
                  child: SizedBox(
                    height: 62,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_lensController, _swellController]),
                      builder: (context, _) {
                        final lensPos = _lensController.value;
                        final swell = reduceMotion
                            ? 0.0
                            : Curves.easeOutCubic.transform(_swellController.value);

                        // Velocity-based horizontal stretch (droplet elongation).
                        final velocity = _isDragging
                            ? _dragVelocityTabs
                            : (_lensController.isAnimating ? _lensController.velocity : 0.0);
                        final stretchFactor = reduceMotion
                            ? 0.0
                            : (velocity.abs() / 12.0).clamp(0.0, 0.16);

                        final lensWidth = (tabWidth - 6).clamp(0.0, double.infinity) *
                            (1.0 + stretchFactor);
                        final centerX = (lensPos + 0.5) * tabWidth;
                        final lensLeft = centerX - lensWidth / 2;
                        final lensScale = 1.0 + (swell * 0.055);
                        final lensHeightScale = 1.0 - (stretchFactor * 0.18) + (swell * 0.03);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Sliding Liquid Glass Lens (custom-painted, zero extra BackdropFilter).
                            Positioned(
                              key: const ValueKey('liquid_glass_nav_lens'),
                              left: lensLeft,
                              top: 3,
                              bottom: 3,
                              width: lensWidth,
                              child: Transform.scale(
                                scaleX: lensScale,
                                scaleY: lensScale * lensHeightScale,
                                child: CustomPaint(
                                  painter: _LiquidGlassLensPainter(
                                    colorScheme: colorScheme,
                                    isDark: isDark,
                                    swell: swell,
                                  ),
                                ),
                              ),
                            ),

                            // Destination items with continuous proximity choreography.
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(count, (index) {
                                  final dest = widget.destinations[index];
                                  final isSelected = index == widget.currentIndex;

                                  // Continuous proximity [0..1] as the lens glides over tabs.
                                  final proximity = reduceMotion
                                      ? (isSelected ? 1.0 : 0.0)
                                      : (1.0 - (index - lensPos).abs()).clamp(0.0, 1.0);
                                  final highlight = Curves.easeOut.transform(proximity);

                                  final activeColor = isDark
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.primary;
                                  final inactiveColor = colorScheme.onSurfaceVariant
                                      .withAlpha(isDark ? 205 : 220);
                                  final itemColor = Color.lerp(
                                    inactiveColor,
                                    activeColor,
                                    highlight,
                                  )!;

                                  final iconScale = lerpDouble(1.0, 1.10, highlight)!;
                                  final showSelectedIcon = highlight > 0.5;

                                  return Expanded(
                                    child: Semantics(
                                      button: true,
                                      selected: isSelected,
                                      label: dest.label,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _handleTap(index),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Transform.scale(
                                                scale: iconScale,
                                                child: Icon(
                                                  showSelectedIcon
                                                      ? dest.selectedIcon
                                                      : dest.icon,
                                                  size: 22,
                                                  color: itemColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                dest.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: itemColor,
                                                  height: 1.15,
                                                  fontWeight: highlight > 0.5
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  letterSpacing:
                                                      highlight > 0.5 ? 0.1 : 0.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the refractive iOS 26 Liquid Glass pill lens:
/// 1. Soft ambient glow/elevation shadow beneath the droplet.
/// 2. Luminous translucent directional gradient fill.
/// 3. Convex top-edge specular catchlight band.
/// 4. Crisp two-tone specular outer rim + subtle inset highlight stroke.
class _LiquidGlassLensPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final bool isDark;
  final double swell;

  const _LiquidGlassLensPainter({
    required this.colorScheme,
    required this.isDark,
    required this.swell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Ambient lens shadow / colored glow.
    final shadowAlpha = isDark
        ? (44 + (swell * 30)).round()
        : (24 + (swell * 16)).round();
    final shadowPaint = Paint()
      ..color = (isDark ? colorScheme.primary : Colors.black).withAlpha(shadowAlpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + swell * 4);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // 2. Refractive glass body gradient.
    final topColor = isDark
        ? Color.alphaBlend(
            Colors.white.withAlpha((34 + swell * 18).round()),
            colorScheme.primaryContainer.withAlpha(185),
          )
        : Color.alphaBlend(
            Colors.white.withAlpha(215),
            colorScheme.primaryContainer.withAlpha(140),
          );
    final bottomColor = isDark
        ? colorScheme.primary.withAlpha(105)
        : colorScheme.primaryContainer.withAlpha(185);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topColor, bottomColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 3. Convex top-edge specular catchlight.
    canvas.save();
    canvas.clipRRect(rrect);
    final glossRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.48);
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withAlpha(isDark ? (46 + swell * 22).round() : 145),
          Colors.white.withAlpha(0),
        ],
      ).createShader(glossRect);
    canvas.drawRect(glossRect, glossPaint);
    canvas.restore();

    // 4. Two-tone specular rim.
    final rimRRect = RRect.fromRectAndRadius(
      rect.deflate(0.55),
      Radius.circular(radius),
    );
    final rimTop = Colors.white.withAlpha(isDark ? (145 + swell * 40).round() : 245);
    final rimBottom = isDark
        ? colorScheme.primary.withAlpha(75)
        : colorScheme.primary.withAlpha(55);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          rimTop,
          Color.lerp(rimTop, rimBottom, 0.55)!,
          rimBottom,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, rimPaint);

    // 5. Subtle inset highlight stroke for 3D lens thickness.
    final insetRRect = RRect.fromRectAndRadius(
      rect.deflate(1.9),
      Radius.circular((radius - 1.9).clamp(0.0, double.infinity)),
    );
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withAlpha(isDark ? 42 : 130),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRRect(insetRRect, insetPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassLensPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.isDark != isDark ||
        oldDelegate.swell != swell;
  }
}
