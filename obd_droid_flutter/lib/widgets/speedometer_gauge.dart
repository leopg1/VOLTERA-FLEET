import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../theme/app_theme.dart';

/// Speedometer 0–260 km/h. Single accent (cyan) — verde / portocaliu / rosu
/// raman doar pentru zonele de status (range colorate la limite).
class SpeedometerGauge extends StatelessWidget {
  final double value;
  final double max;

  const SpeedometerGauge({
    super.key,
    required this.value,
    this.max = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      enableLoadingAnimation: false,
      animationDuration: 700,
      axes: <RadialAxis>[
        // Background trough (full arc, faint)
        RadialAxis(
          minimum: 0,
          maximum: max,
          startAngle: 135,
          endAngle: 45,
          showLabels: false,
          showTicks: false,
          axisLineStyle: AxisLineStyle(
            thickness: 14,
            color: AppColors.surfaceLo,
            cornerStyle: CornerStyle.bothCurve,
          ),
        ),
        // Status range arc (verde/galben/rosu) — semantic
        RadialAxis(
          minimum: 0,
          maximum: max,
          startAngle: 135,
          endAngle: 45,
          showLabels: true,
          showTicks: true,
          interval: max / 6.5,
          minorTicksPerInterval: 4,
          radiusFactor: 1.0,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.5,
            color: Colors.transparent,
          ),
          majorTickStyle: const MajorTickStyle(
            length: 9,
            thickness: 1.4,
            color: AppColors.textDim,
          ),
          minorTickStyle: const MinorTickStyle(
            length: 4,
            thickness: 1,
            color: AppColors.textDim,
          ),
          axisLabelStyle: GaugeTextStyle(
            color: AppColors.textMuted,
            fontFamily: 'Rajdhani',
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 80,
              color: AppColors.ok.withOpacity(0.55),
              startWidth: 4,
              endWidth: 4,
            ),
            GaugeRange(
              startValue: 80,
              endValue: 150,
              color: AppColors.warn.withOpacity(0.55),
              startWidth: 4,
              endWidth: 4,
            ),
            GaugeRange(
              startValue: 150,
              endValue: max,
              color: AppColors.danger.withOpacity(0.55),
              startWidth: 4,
              endWidth: 4,
            ),
          ],
          pointers: <GaugePointer>[
            // Cyan progress arc (the actual "filled" part)
            RangePointer(
              value: value.clamp(0, max).toDouble(),
              width: 14,
              cornerStyle: CornerStyle.bothCurve,
              color: AppColors.cyan,
              gradient: SweepGradient(
                colors: [AppColors.cyanDeep, AppColors.cyan],
                stops: const [0.0, 1.0],
              ),
              enableAnimation: true,
              animationType: AnimationType.ease,
            ),
            NeedlePointer(
              value: value.clamp(0, max).toDouble(),
              needleLength: 0.78,
              needleStartWidth: 1.0,
              needleEndWidth: 4,
              needleColor: AppColors.cyan,
              enableAnimation: true,
              animationType: AnimationType.ease,
              knobStyle: const KnobStyle(
                knobRadius: 0.07,
                color: AppColors.bg,
                borderColor: AppColors.cyan,
                borderWidth: 0.035,
              ),
              tailStyle: const TailStyle(
                length: 0.12,
                width: 3,
                color: AppColors.cyan,
              ),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              positionFactor: 0.55,
              angle: 90,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.isNaN ? '—' : value.toStringAsFixed(0),
                    style: AppText.digital(
                      size: 36,
                      color: AppColors.cyan,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('km/h',
                      style: AppText.label(
                          size: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
