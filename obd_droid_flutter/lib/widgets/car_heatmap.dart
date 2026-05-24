import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Top-view masina cu HEATMAP overlay live.
///
/// Maparea zonelor termice este derivata din PID-uri OBD:
///  - ECT (coolant)            -> motor (engine bay) front
///  - IAT (intake air temp)    -> intake (front grill)
///  - EOT (engine oil temp)    -> centru motor
///  - Engine load %            -> intensitate generala
///  - Speed (km/h)             -> jante (frana incalzita)
///  - Throttle (%)             -> intake punch
///  - Exhaust (estimat ECT+30) -> rear/exhaust
///
/// Render: SVG-ul masinii din `assets/images/car_top.svg` este pictat in
/// alb cu transparenta apoi peste el desenam zonele heatmap (gradient radial)
/// si o silueta cyan slaba ca contur. Rezultatul: imaginea se simte "vie",
/// fara sa mai fie un simplu desen static.
class CarHeatmap extends StatefulWidget {
  /// Coolant temperature °C (PID 0x05).
  final double? coolant;

  /// Intake air temperature °C (PID 0x0F).
  final double? intakeTemp;

  /// Engine load 0..100 (PID 0x04).
  final double? engineLoad;

  /// Throttle position 0..100 (PID 0x11).
  final double? throttle;

  /// Vehicle speed km/h (PID 0x0D).
  final double? speed;

  /// Engine oil temperature °C (PID 0x5C). Optional.
  final double? oilTemp;

  /// True when the heat blobs should pulsate to show telemetry is live.
  final bool live;

  const CarHeatmap({
    super.key,
    this.coolant,
    this.intakeTemp,
    this.engineLoad,
    this.throttle,
    this.speed,
    this.oilTemp,
    this.live = true,
  });

  @override
  State<CarHeatmap> createState() => _CarHeatmapState();
}

class _CarHeatmapState extends State<CarHeatmap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pulse = 0.85 + 0.15 * _ctrl.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              // Layer 1: subtle background ring
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withOpacity(0.05 * pulse),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Layer 2: heatmap blobs
              CustomPaint(
                painter: _HeatmapPainter(
                  coolant: widget.coolant,
                  intakeTemp: widget.intakeTemp,
                  engineLoad: widget.engineLoad,
                  throttle: widget.throttle,
                  speed: widget.speed,
                  oilTemp: widget.oilTemp,
                  pulse: widget.live ? pulse : 1.0,
                ),
              ),
              // Layer 3: car silhouette tinted cyan
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SvgPicture.asset(
                  'assets/images/car_top.svg',
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(
                    AppColors.cyan.withOpacity(0.85),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              // Layer 4: heat scale legend
              Positioned(
                left: 6,
                top: 6,
                child: _HeatLegend(),
              ),
              if (widget.live)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLo.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.cyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(pulse),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'HEAT',
                          style: AppText.label(
                              size: 8.5,
                              color: AppColors.cyan,
                              weight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final double? coolant;
  final double? intakeTemp;
  final double? engineLoad;
  final double? throttle;
  final double? speed;
  final double? oilTemp;
  final double pulse;

  _HeatmapPainter({
    required this.coolant,
    required this.intakeTemp,
    required this.engineLoad,
    required this.throttle,
    required this.speed,
    required this.oilTemp,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Coordonate normalizate (0..1) — convertite la pixeli
    Offset xy(double nx, double ny) => Offset(nx * size.width, ny * size.height);

    // ---- Engine bay (front of car) — coolant + load
    final ectN = _normalizeTemp(coolant, low: 60, high: 110);
    final loadN = ((engineLoad ?? 0) / 100).clamp(0.0, 1.0);
    final engineHeat = (ectN * 0.7 + loadN * 0.3).clamp(0.0, 1.0);
    _paintBlob(
      canvas,
      center: xy(0.5, 0.18),
      radius: size.width * 0.32 * pulse,
      heat: engineHeat,
      label: null,
    );

    // ---- Intake (very front)
    final iatN = _normalizeTemp(intakeTemp, low: 10, high: 70);
    final tpsN = ((throttle ?? 0) / 100).clamp(0.0, 1.0);
    final intakeHeat = (iatN * 0.5 + tpsN * 0.5).clamp(0.0, 1.0);
    _paintBlob(
      canvas,
      center: xy(0.5, 0.06),
      radius: size.width * 0.22 * pulse,
      heat: intakeHeat,
    );

    // ---- Oil pan / center — oil temp or fall back to coolant
    final eotN = _normalizeTemp(
      oilTemp ?? (coolant != null ? coolant! + 10 : null),
      low: 60,
      high: 130,
    );
    _paintBlob(
      canvas,
      center: xy(0.5, 0.42),
      radius: size.width * 0.20 * pulse,
      heat: eotN,
    );

    // ---- Exhaust (rear) — derived from coolant + load (proxy)
    final exh = ((ectN + loadN) / 2).clamp(0.0, 1.0);
    _paintBlob(
      canvas,
      center: xy(0.5, 0.92),
      radius: size.width * 0.26 * pulse,
      heat: exh * 0.9,
    );

    // ---- Wheels — brake heat ~ proportional to speed (proxy)
    final spN = ((speed ?? 0) / 200).clamp(0.0, 1.0);
    final wheelHeat = (spN * 0.7).clamp(0.0, 1.0);
    final wheelR = size.width * 0.10 * pulse;
    _paintBlob(canvas, center: xy(0.13, 0.27), radius: wheelR, heat: wheelHeat);
    _paintBlob(canvas, center: xy(0.87, 0.27), radius: wheelR, heat: wheelHeat);
    _paintBlob(canvas, center: xy(0.13, 0.74), radius: wheelR, heat: wheelHeat);
    _paintBlob(canvas, center: xy(0.87, 0.74), radius: wheelR, heat: wheelHeat);

    // Tiny temperature readings overlay
    _paintTempLabel(canvas, xy(0.5, 0.18), coolant, 'ECT');
    _paintTempLabel(canvas, xy(0.5, 0.92), _exhaustEstimate(coolant, engineLoad),
        'EXH');
  }

  double? _exhaustEstimate(double? c, double? load) {
    if (c == null) return null;
    final extra = (load ?? 30) * 1.5;
    return c + extra;
  }

  void _paintTempLabel(Canvas canvas, Offset c, double? value, String label) {
    if (value == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '${value.toStringAsFixed(0)}°',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lbl = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.cyan,
          fontFamily: 'Rajdhani',
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    lbl.paint(canvas, Offset(c.dx - lbl.width / 2, c.dy + tp.height / 2));
  }

  void _paintBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double heat,
    String? label,
  }) {
    final color = _heatColor(heat);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.65 * heat.clamp(0.15, 1.0)),
          color.withOpacity(0.18 * heat.clamp(0.15, 1.0)),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  /// Maps a temperature value to 0..1 within the [low..high] band.
  double _normalizeTemp(double? value, {required double low, required double high}) {
    if (value == null) return 0.0;
    if (high == low) return 0.0;
    return ((value - low) / (high - low)).clamp(0.0, 1.0);
  }

  /// Gradient: blue (cool) -> green -> yellow -> orange -> red (hot).
  Color _heatColor(double heat) {
    final h = heat.clamp(0.0, 1.0);
    if (h < 0.25) {
      return Color.lerp(AppColors.cyan, AppColors.ok, h / 0.25)!;
    }
    if (h < 0.55) {
      return Color.lerp(AppColors.ok, AppColors.warn, (h - 0.25) / 0.30)!;
    }
    if (h < 0.85) {
      return Color.lerp(AppColors.warn, AppColors.danger, (h - 0.55) / 0.30)!;
    }
    return AppColors.danger;
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.coolant != coolant ||
      old.intakeTemp != intakeTemp ||
      old.engineLoad != engineLoad ||
      old.throttle != throttle ||
      old.speed != speed ||
      old.oilTemp != oilTemp ||
      old.pulse != pulse;
}

class _HeatLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLo.withOpacity(0.78),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [
                  AppColors.cyan,
                  AppColors.ok,
                  AppColors.warn,
                  AppColors.danger,
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('°C',
              style: AppText.label(
                  size: 8, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
