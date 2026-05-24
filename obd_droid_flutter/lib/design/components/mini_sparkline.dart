import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';

/// Sparkline subtila — stroke 1.5dp, fara fill, fara glow.
/// Folosita inline in MetricBlock pentru "trend rapid".
class MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double strokeWidth;

  const MiniSparkline({
    super.key,
    required this.values,
    this.color,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CustomPaint(
      painter: _SparklinePainter(
        values: values,
        color: color ?? t.accent,
        strokeWidth: strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    double minV = values.first, maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final dx = size.width / (values.length - 1);
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
