import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../theme/app_theme.dart';

class TelemetrySample {
  final DateTime t;
  final double rpm;
  final double engineTemp;
  TelemetrySample(this.t, this.rpm, this.engineTemp);
}

/// Real-time line chart pentru ultimele 60 secunde.
/// RPM = cyan, Engine Temp = portocaliu (semantic: temperature warmth).
class LiveTelemetryChart extends StatelessWidget {
  final List<TelemetrySample> samples;

  const LiveTelemetryChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(seconds: 60));

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      plotAreaBackgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(0, 4, 6, 4),
      primaryXAxis: DateTimeAxis(
        minimum: start,
        maximum: now,
        intervalType: DateTimeIntervalType.seconds,
        majorGridLines: const MajorGridLines(
          width: 0.5,
          color: Color(0x10FFFFFF),
        ),
        majorTickLines: const MajorTickLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppText.label(size: 9, color: AppColors.textDim),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 8000,
        interval: 2000,
        majorGridLines: const MajorGridLines(
          width: 0.5,
          color: Color(0x10FFFFFF),
        ),
        majorTickLines: const MajorTickLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppText.label(size: 9, color: AppColors.textDim),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'tempAxis',
          opposedPosition: true,
          minimum: 0,
          maximum: 130,
          interval: 30,
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: AppText.label(size: 9, color: AppColors.textDim),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: AppColors.surfaceHi,
        borderColor: AppColors.cyan,
        borderWidth: 1,
        textStyle: AppText.body(size: 11, weight: FontWeight.w700),
      ),
      series: <CartesianSeries<TelemetrySample, DateTime>>[
        // RPM area underlay (subtle cyan glow)
        AreaSeries<TelemetrySample, DateTime>(
          name: 'RPM',
          dataSource: samples,
          xValueMapper: (s, _) => s.t,
          yValueMapper: (s, _) => s.rpm,
          gradient: LinearGradient(
            colors: [
              AppColors.cyan.withOpacity(0.30),
              AppColors.cyan.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderWidth: 0,
        ),
        FastLineSeries<TelemetrySample, DateTime>(
          name: 'RPM',
          dataSource: samples,
          xValueMapper: (s, _) => s.t,
          yValueMapper: (s, _) => s.rpm,
          color: AppColors.cyan,
          width: 2.2,
        ),
        FastLineSeries<TelemetrySample, DateTime>(
          name: 'Temp',
          dataSource: samples,
          xValueMapper: (s, _) => s.t,
          yValueMapper: (s, _) => s.engineTemp,
          color: AppColors.warn,
          width: 2,
          dashArray: const <double>[4, 3],
          yAxisName: 'tempAxis',
        ),
      ],
    );
  }
}
