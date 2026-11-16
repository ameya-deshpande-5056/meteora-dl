import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Default metrics directly matching Morphe App and Jetpack Compose Material 3 Expressive
/// `WavyProgressIndicatorDefaults`, tuned for sleekness, clarity, and mobile density.
const double kDefaultBarStrokeWidth = 4.0; // Sleek 4.dp M3 Expressive stroke width
const double kDefaultBarHeight = 14.0; // Proportional 14.dp container height
const double kDefaultWavelength = 22.0; // M3 LinearDeterminateWavelength = 22.dp
const double kDefaultIndeterminateWavelength = 20.0;
const double kDefaultGapSize = 4.0; // M3 LinearIndicatorTrackGapSize = 4.dp
const double kDefaultRingStrokeWidth = 6.0; // Sleek circular ring stroke width
const double kDefaultLeftPadding = 2.0; // Start margin ensuring round cap clears container
const double kDefaultRightPadding = 4.0; // Clean right-side padding for uniform termination

/// Material 3 Expressive wavy progress indicator, modeled with pixel and behavioral
/// fidelity to Morphe App (`WavyProgressBar`), MicroG RE, and Google Play Store.
///
/// Features:
/// - **The track is a flat, straight line** in `surfaceContainerHighest` with rounded caps.
/// - **The active progress is a smooth, continuous sinusoidal wave** that actively dances
///   (propagates horizontally) during download transfers, matching Morphe and Google Play Store.
/// - **Smooth end-point tapering**: The wave smoothly anchors to `centerY` at the start and
///   terminating end, ensuring rounded caps are perfectly centered and uniform.
/// - **Right-side padding (`rightPadding = 4.0dp`)**: Gives the terminating wave and track
///   balanced breathing room, identical to how it begins.
/// - **Physical gap (`gapSize = 4.0dp`)**: Separates the active wave tip from the flat track.
/// - When the platform requests reduced motion, falls back cleanly to a linear progress indicator.
class WavyProgressIndicator extends StatefulWidget {
  /// 0.0–1.0 for determinate progress, or null for indeterminate.
  final double? value;
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double height;
  final double gapSize;
  final double stopSize;
  final double leftPadding;
  final double rightPadding;
  final bool isAnimating;

  const WavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.trackColor,
    this.strokeWidth = kDefaultBarStrokeWidth,
    this.amplitude = 1.0,
    this.wavelength = kDefaultWavelength,
    this.height = kDefaultBarHeight,
    this.gapSize = kDefaultGapSize,
    this.stopSize = 0.0,
    this.leftPadding = kDefaultLeftPadding,
    this.rightPadding = kDefaultRightPadding,
    this.isAnimating = true,
  });

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.progressCycle,
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant WavyProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnimating != widget.isAnimating ||
        oldWidget.value != widget.value) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isAnimating) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.color ?? colorScheme.primary;
    final trackColor = widget.trackColor ?? colorScheme.surfaceContainerHighest;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isIndeterminate = widget.value == null;
    final clamped = widget.value?.clamp(0.0, 1.0).toDouble();

    if (isIndeterminate && reduceMotion) {
      return Semantics(
        label: 'Loading',
        child: LinearProgressIndicator(
          minHeight: widget.strokeWidth,
          color: color,
          backgroundColor: trackColor,
        ),
      );
    }

    final effectiveAnimating = widget.isAnimating && !reduceMotion;

    return Semantics(
      label: isIndeterminate ? 'Loading' : 'Progress',
      value: clamped == null ? null : '${(clamped * 100).round()}%',
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = effectiveAnimating ? _controller.value : 0.0;
              return CustomPaint(
                painter: _MorpheLinearWavyPainter(
                  progress: clamped,
                  phase: phase,
                  color: color,
                  trackColor: trackColor,
                  strokeWidth: widget.strokeWidth,
                  amplitude: widget.amplitude,
                  wavelength: isIndeterminate
                      ? kDefaultIndeterminateWavelength
                      : widget.wavelength,
                  gapSize: widget.gapSize,
                  stopSize: widget.stopSize,
                  height: widget.height,
                  leftPadding: widget.leftPadding,
                  rightPadding: widget.rightPadding,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Custom painter implementing the exact quadratic wave geometry, flat track,
/// dancing phase translation, and gap metrics matching AndroidX Material 3
/// Expressive `LinearWavyProgressModifiers.kt` and Morphe App.
class _MorpheLinearWavyPainter extends CustomPainter {
  final double? progress;
  final double phase; // 0.0 .. 1.0 continuous animation phase evaluated per frame
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double gapSize;
  final double stopSize;
  final double height;
  final double leftPadding;
  final double rightPadding;

  // Material 3 Expressive indeterminate intervals
  static const Curve _line1Head = Interval(
    0.0,
    750.0 / 1800.0,
    curve: Cubic(0.2, 0.0, 0.8, 1.0),
  );
  static const Curve _line1Tail = Interval(
    333.0 / 1800.0,
    1083.0 / 1800.0,
    curve: Cubic(0.4, 0.0, 1.0, 1.0),
  );
  static const Curve _line2Head = Interval(
    1000.0 / 1800.0,
    1567.0 / 1800.0,
    curve: Cubic(0.0, 0.0, 0.65, 1.0),
  );
  static const Curve _line2Tail = Interval(
    1267.0 / 1800.0,
    1800.0 / 1800.0,
    curve: Cubic(0.10, 0.0, 0.45, 1.0),
  );

  // Cached master wave path and metric to avoid re-allocating and re-measuring native paths on every vsync
  static double? _cachedWidth;
  static double? _cachedHeight;
  static double? _cachedStrokeWidth;
  static double? _cachedWavelength;
  static double? _cachedAmplitude;
  static PathMetric? _cachedMetric;
  static double _cachedPathScale = 1.0;

  const _MorpheLinearWavyPainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
    required this.gapSize,
    required this.stopSize,
    required this.height,
    required this.leftPadding,
    required this.rightPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0) return;

    final double width = size.width;
    final double centerY = size.height / 2.0;
    final double capRadius = strokeWidth / 2.0;

    final double startX = capRadius + leftPadding;
    final double trackEndX = math.max(startX, width - capRadius - rightPadding);
    final double availableSpan = trackEndX - startX;
    if (availableSpan <= 0) return;

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor
      ..isAntiAlias = true;

    final Paint indicatorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color
      ..isAntiAlias = true;

    // Master continuous quadratic wave path matching AndroidX
    // `LinearWavyProgressModifiers.kt` `updateFullPaths`. Reused across animation ticks.
    final double halfWl = math.max(4.0, wavelength / 2.0);
    final double cY = (height - strokeWidth) * math.min(1.0, amplitude);
    final double totalW = width + wavelength * 3.0;

    PathMetric metric;
    double pathScale;

    if (_cachedMetric != null &&
        _cachedWidth == width &&
        _cachedHeight == height &&
        _cachedStrokeWidth == strokeWidth &&
        _cachedWavelength == wavelength &&
        _cachedAmplitude == amplitude) {
      metric = _cachedMetric!;
      pathScale = _cachedPathScale;
    } else {
      final Path fullPath = Path();
      fullPath.moveTo(0.0, centerY);
      double x = 0.0;
      double currentCY = cY;
      while (x <= totalW) {
        fullPath.quadraticBezierTo(
          x + halfWl / 2.0,
          centerY + currentCY,
          x + halfWl,
          centerY,
        );
        x += halfWl;
        currentCY = -currentCY;
      }
      metric = fullPath.computeMetrics().first;
      pathScale = metric.length / x;

      _cachedWidth = width;
      _cachedHeight = height;
      _cachedStrokeWidth = strokeWidth;
      _cachedWavelength = wavelength;
      _cachedAmplitude = amplitude;
      _cachedMetric = metric;
      _cachedPathScale = pathScale;
    }

    final double waveShift = (phase % 1.0) * wavelength;

    void drawWavySegment(double segStartX, double segEndX) {
      if (segEndX <= segStartX) return;
      final double startDist = (segStartX + waveShift) * pathScale;
      final double stopDist = (segEndX + waveShift) * pathScale;
      final Path segment = metric.extractPath(startDist, stopDist);

      canvas.save();
      canvas.translate(-waveShift, 0.0);
      canvas.drawPath(segment, indicatorPaint);
      canvas.restore();
    }

    // 1. Determinate Progress Mode
    if (progress != null) {
      final double p = progress!.clamp(0.0, 1.0);

      // 0% progress: clean flat track spans the full width
      if (p <= 0.0) {
        canvas.drawLine(
          Offset(startX, centerY),
          Offset(trackEndX, centerY),
          trackPaint,
        );
        return;
      }

      final double activeEndX = (startX + availableSpan * p).clamp(startX, trackEndX);

      // 100% progress: full dancing wavy indicator
      if (p >= 1.0) {
        drawWavySegment(startX, trackEndX);
        return;
      }

      // Partial progress: active dancing wave from startX to activeEndX
      drawWavySegment(startX, activeEndX);

      // Flat track starts after activeEndX + gapSize + capRadius * 2
      final double trackStartX = activeEndX + gapSize + capRadius * 2.0;
      if (trackStartX < trackEndX) {
        canvas.drawLine(
          Offset(trackStartX, centerY),
          Offset(trackEndX, centerY),
          trackPaint,
        );
      }

      // Optional stop indicator dot
      if (stopSize > 0 && trackEndX > trackStartX) {
        canvas.drawCircle(
          Offset(trackEndX, centerY),
          stopSize / 2.0,
          Paint()..color = color,
        );
      }
      return;
    }

    // 2. Indeterminate Mode: Two overlapping Material 3 Expressive waveform lines
    final double h1 = _line1Head.transform(phase);
    final double t1 = _line1Tail.transform(phase);
    final double h2 = _line2Head.transform(phase);
    final double t2 = _line2Tail.transform(phase);

    final bool line1Active = (h1 - t1) > 0.005;
    final bool line2Active = (h2 - t2) > 0.005;

    // Fallback pulse ensures indicator is never invisible at phase == 0.0 / cycle boundary
    if (!line1Active && !line2Active) {
      final double fallbackHead = startX + availableSpan * 0.28;
      drawWavySegment(startX, fallbackHead);
      final double gapTrackStart = fallbackHead + gapSize + capRadius * 2.0;
      if (gapTrackStart < trackEndX) {
        canvas.drawLine(
          Offset(gapTrackStart, centerY),
          Offset(trackEndX, centerY),
          trackPaint,
        );
      }
      return;
    }

    // Draw baseline flat track across full width
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(trackEndX, centerY),
      trackPaint,
    );

    // Overlay active traveling wave segments
    if (line1Active) {
      final double s1 = (startX + availableSpan * t1).clamp(startX, trackEndX);
      final double e1 = (startX + availableSpan * h1).clamp(startX, trackEndX);
      drawWavySegment(s1, e1);
    }

    if (line2Active) {
      final double s2 = (startX + availableSpan * t2).clamp(startX, trackEndX);
      final double e2 = (startX + availableSpan * h2).clamp(startX, trackEndX);
      drawWavySegment(s2, e2);
    }
  }

  @override
  bool shouldRepaint(covariant _MorpheLinearWavyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.gapSize != gapSize ||
        oldDelegate.stopSize != stopSize ||
        oldDelegate.height != height ||
        oldDelegate.leftPadding != leftPadding ||
        oldDelegate.rightPadding != rightPadding;
  }
}

/// Circular wavy progress ring directly modeled on Morphe App's `WavyProgressRing`.
class CircularWavyProgressIndicator extends StatefulWidget {
  final double? value;
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;
  final double diameter;
  final int waveCount;
  final bool isAnimating;

  const CircularWavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.trackColor,
    this.strokeWidth = kDefaultRingStrokeWidth,
    this.diameter = 56.0,
    this.waveCount = 8,
    this.isAnimating = true,
  });

  @override
  State<CircularWavyProgressIndicator> createState() =>
      _CircularWavyProgressIndicatorState();
}

class _CircularWavyProgressIndicatorState
    extends State<CircularWavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.progressCycle,
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CircularWavyProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnimating != widget.isAnimating) {
      if (widget.isAnimating && !_controller.isAnimating) {
        _controller.repeat();
      } else if (!widget.isAnimating && _controller.isAnimating) {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.color ?? colorScheme.primary;
    final trackColor = widget.trackColor ?? colorScheme.surfaceContainerHighest;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final clamped = widget.value?.clamp(0.0, 1.0).toDouble();
    final effectiveAnimating = widget.isAnimating && !reduceMotion;

    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = effectiveAnimating ? _controller.value : 0.0;
          return CustomPaint(
            painter: _CircularWavyPainter(
              progress: clamped,
              phase: phase,
              color: color,
              trackColor: trackColor,
              strokeWidth: widget.strokeWidth,
              waveCount: widget.waveCount,
            ),
          );
        },
      ),
    );
  }
}

class _CircularWavyPainter extends CustomPainter {
  final double? progress;
  final double phase;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final int waveCount;

  const _CircularWavyPainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.waveCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2.0;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final Paint indicatorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Draw circular flat track
    canvas.drawCircle(center, radius, trackPaint);

    final double sweep = (progress ?? 0.35) * 2 * math.pi;
    final double startAngle = -math.pi / 2 + (progress == null ? phase * 2 * math.pi : 0.0);

    // Active undulating circular arc
    final Path wavePath = Path();
    const int steps = 120;
    final double waveAmp = strokeWidth * 0.35;

    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double theta = startAngle + t * sweep;
      final double r = radius + waveAmp * math.sin(theta * waveCount + phase * 2 * math.pi);
      final double x = center.dx + r * math.cos(theta);
      final double y = center.dy + r * math.sin(theta);

      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }

    canvas.drawPath(wavePath, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularWavyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.waveCount != waveCount;
  }
}
