import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../theme/app_theme.dart';

/// Tachometer 0–8000 RPM. Single accent (cyan); redline marcat cu arc rosu
/// subtil 6500+ pentru status, restul cyan.
class TachometerGauge extends StatelessWidget {
  final double value;
  final double max;
  final double redline;

  const TachometerGauge({
    super.key,
    required this.value,
    this.max = 8000,
    this.redline = 6500,
  });

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      enableLoadingAnimation: false,
      animationDuration: 600,
      axes: <RadialAxis>[
        // Background trough
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
        RadialAxis(
          minimum: 0,
          maximum: max,
          startAngle: 135,
          endAngle: 45,
          showLabels: true,
          showTicks: true,
          interval: 1000,
          minorTicksPerInterval: 4,
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
          onLabelCreated: (args) {
            args.text = (double.parse(args.text) / 1000).toStringAsFixed(0);
          },
          ranges: <GaugeRange>[
            // Redline status range
            GaugeRange(
              startValue: redline,
              endValue: max,
              color: AppColors.danger.withOpacity(0.6),
              startWidth: 4,
              endWidth: 4,
            ),
          ],
          pointers: <GaugePointer>[
            RangePointer(
              value: value.clamp(0, max).toDouble(),
              width: 14,
              cornerStyle: CornerStyle.bothCurve,
              gradient: SweepGradient(
                colors: [
                  AppColors.cyanDeep,
                  AppColors.cyan,
                  if (value > redline) AppColors.danger,
                ],
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
                      size: 30,
                      color: AppColors.cyan,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('rpm',
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
