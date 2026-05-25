import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'status_dot.dart';

/// Arc 270° subtire, 4dp stroke. Inlocuieste gauge-urile skeuomorfice.
/// Center = un MetricBlock-like (label/11 + display + unit).
/// O singura culoare (semantic), nicio "needle", niciun glow.
class LiveArcMeter extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String? unit;
  final VStatus status;
  final double thickness;
  final double sweepDegrees; // default 270
  final Widget? footer;

  const LiveArcMeter({
    super.key,
    required this.value,
    this.min = 0,
    required this.max,
    required this.label,
    this.unit,
    this.status = VStatus.info,
    this.thickness = 4,
    this.sweepDegrees = 270,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final color = status.resolve(t);

    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      // Scale text to fit. <120 = compact (small badge), 120-220 = medium,
      // 220+ = hero. Padding scales with size too.
      final compact = size < 140;
      final numberStyle = compact
          ? VType.display40.copyWith(
              color: t.textStrong,
              fontSize: size * 0.32,
              fontFamily: VType.mono,
              fontFeatures: const [FontFeature.tabularFigures()],
            )
          : size < 240
              ? VType.display40.copyWith(
                  color: t.textStrong,
                  fontFamily: VType.mono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )
              : VType.display72.copyWith(color: t.textStrong);
      final pad = compact ? VSpace.s8 : VSpace.s20;
      final showLabel = !compact;
      final labelStyle = VType.label11.copyWith(color: t.textMuted);

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _ArcPainter(
                progress: progress,
                color: color,
                trackColor: t.hairline,
                thickness: thickness,
                sweepDegrees: sweepDegrees,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLabel) ...[
                    Text(label.toUpperCase(), style: labelStyle),
                    const SizedBox(height: VSpace.s8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _AnimatedNumber(
                        value: value,
                        style: numberStyle,
                      ),
                    ),
                  ),
                  if (unit != null && !compact) ...[
                    const SizedBox(height: VSpace.s4),
                    Text(unit!,
                        style: VType.body15.copyWith(color: t.textMuted)),
                  ],
                  if (footer != null && !compact) ...[
                    const SizedBox(height: VSpace.s8),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double thickness;
  final double sweepDegrees;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.thickness,
    required this.sweepDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - thickness,
    );
    final startAngle = math.pi * (1 - (sweepDegrees - 180) / 360);
    final fullSweep = math.pi * sweepDegrees / 180;
    final progSweep = fullSweep * progress;

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, fullSweep, false, track);

    final prog = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, progSweep, false, prog);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.thickness != thickness ||
      old.sweepDegrees != sweepDegrees;
}

class _AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle style;
  const _AnimatedNumber({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: VMotion.numeric,
      curve: Curves.easeOut,
      builder: (context, v, _) => Text(
        v.isNaN ? '—' : v.toStringAsFixed(0),
        style: style,
      ),
    );
  }
}
