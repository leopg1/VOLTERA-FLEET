import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A bespoke radial gauge inspired by automotive cluster instruments.
///
/// Built without third-party packages so the look is fully ours: a chromed
/// outer ring, an electric arc that fills based on the value, and a recessed
/// inner pad for the digital readout.
class PrimaryGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String unit;
  final Color color;
  final double redlineFraction; // 0..1 of arc beyond which we redline
  final double size;

  const PrimaryGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.unit,
    this.color = AppColors.accent,
    this.redlineFraction = 0.85,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    final fraction = ((clamped - min) / (max - min)).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          fraction: fraction.toDouble(),
          color: color,
          redline: redlineFraction,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNaN ? '—' : value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unit,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double redline;

  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.redline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;

    const startAngle = 3 * pi / 4;
    const sweepAngle = 6 * pi / 4;

    final track = Paint()
      ..color = AppColors.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      track,
    );

    final isRed = fraction >= redline;
    final stroke = Paint()
      ..shader = SweepGradient(
        colors: isRed
            ? [AppColors.warn, AppColors.danger]
            : [color.withOpacity(0.6), color],
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction,
      false,
      stroke,
    );

    // Inner highlight ring
    final innerRing = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 16, innerRing);

    // Tick marks
    final tickPaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.5)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final angle = startAngle + sweepAngle * t;
      final inner = center +
          Offset(cos(angle) * (radius - 22), sin(angle) * (radius - 22));
      final outer = center +
          Offset(cos(angle) * (radius - 14), sin(angle) * (radius - 14));
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.redline != redline;
}
