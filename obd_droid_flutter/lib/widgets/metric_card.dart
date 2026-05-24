import 'package:flutter/material.dart';

import '../core/models/pid.dart';
import '../theme/app_theme.dart';

/// Lightweight card showing a single PID's current value, ideal for the
/// dashboard grid and the live data screen.
class MetricCard extends StatelessWidget {
  final Pid pid;
  final PidSample? sample;
  final List<double>? sparkline;
  final IconData icon;
  final Color? accent;

  const MetricCard({
    super.key,
    required this.pid,
    required this.sample,
    this.sparkline,
    this.icon = Icons.speed_rounded,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent;
    final value = sample?.value;
    final formatted = sample == null || value == null || value.isNaN
        ? '—'
        : (value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.10),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pid.shortName,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatted,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  pid.unit,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pid.name,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sparkline != null && sparkline!.length > 4) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 28,
              child: CustomPaint(
                size: const Size.fromHeight(28),
                painter: _SparklinePainter(sparkline!, color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final t = (values[i] - minV) / range;
      final x = i * dx;
      final y = size.height - t * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
      ).createShader(Offset.zero & size);
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
