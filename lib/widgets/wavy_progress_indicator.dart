import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Material 3 Expressive wavy progress indicator.
///
/// A determinate indicator draws a static sine wave that fills from the left as
/// [value] grows; an indeterminate indicator sends a travelling wave segment
/// across the track. When the platform requests reduced motion the indeterminate
/// form falls back to a plain [LinearProgressIndicator] so progress is still
/// legible without animation.
class WavyProgressIndicator extends StatefulWidget {
  /// 0.0–1.0 for determinate progress, or null for indeterminate.
  final double? value;
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double height;

  const WavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.trackColor,
    this.strokeWidth = 3.5,
    this.amplitude = 3.0,
    this.wavelength = 26.0,
    this.height = 12.0,
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
    if (oldWidget.value != widget.value) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.value == null) {
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
    final trackColor = widget.trackColor ?? color.withAlpha(46);
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

    return Semantics(
      label: isIndeterminate ? 'Loading' : 'Progress',
      value: clamped == null ? null : '${(clamped * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Own boundary: an animating wave must not repaint the card that
            // contains it (shadow, specular rim, thumbnail) every frame.
            return RepaintBoundary(
              child: CustomPaint(
              painter: _WavyProgressPainter(
                progress: clamped,
                phase: isIndeterminate ? _controller.value : 0.0,
                color: color,
                trackColor: trackColor,
                strokeWidth: widget.strokeWidth,
                amplitude: widget.amplitude,
                wavelength: widget.wavelength,
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double? progress;
  final double phase;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;

  const _WavyProgressPainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
  });

  Path _wavePath(Size size, double phaseOffset) {
    final centerY = size.height / 2;
    final path = Path();
    final step = size.width < 240 ? 2.0 : 1.0;
    for (double x = 0; x <= size.width; x += step) {
      final y = centerY +
          amplitude * math.sin((x / wavelength) * 2 * math.pi + phaseOffset * 2 * math.pi);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Track: the full wave at low opacity.
    paint.color = trackColor;
    canvas.drawPath(_wavePath(size, phase), paint);

    // Filled portion.
    final value = progress;
    paint.color = color;
    if (value != null) {
      if (value <= 0) return;
      final filledWidth = size.width * value;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, filledWidth, size.height));
      canvas.drawPath(_wavePath(size, phase), paint);
      canvas.restore();

      // Leading dot, matching the expressive "active edge" cap.
      final edgeY = size.height / 2 +
          amplitude * math.sin((filledWidth / wavelength) * 2 * math.pi);
      final edgeX = filledWidth.clamp(0.0, size.width).toDouble();
      canvas.drawCircle(
        Offset(edgeX, edgeY),
        strokeWidth * 0.92,
        Paint()..color = color,
      );
      return;
    }

    // Indeterminate: a travelling segment.
    final segmentWidth = size.width * 0.42;
    final start = (phase * 1.55 - 0.3) * size.width;
    final left = start.clamp(-segmentWidth, size.width).toDouble();
    final right = (start + segmentWidth).clamp(0.0, size.width).toDouble();
    if (right <= left) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, 0, right - left, size.height));
    canvas.drawPath(_wavePath(size, phase * 1.6), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength;
  }
}
