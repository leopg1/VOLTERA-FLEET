import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../features/connect/connect_screen.dart';
import '../providers/live_data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/car_heatmap.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/live_telemetry_chart.dart';
import '../widgets/side_metric_card.dart';
import '../widgets/speedometer_gauge.dart';
import '../widgets/tachometer_gauge.dart';
import '../widgets/wide_metric_card.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Queue<TelemetrySample> _samples = Queue<TelemetrySample>();
  Timer? _chartTicker;

  @override
  void initState() {
    super.initState();
    _chartTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final live = context.read<LiveDataProvider>();
      final rpm = live.latest[0x0C]?.value ?? 0.0;
      final temp = live.latest[0x05]?.value ?? 0.0;

      _samples.addLast(TelemetrySample(DateTime.now(), rpm, temp));
      final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
      while (_samples.isNotEmpty && _samples.first.t.isBefore(cutoff)) {
        _samples.removeFirst();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chartTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveDataProvider>();
    final speed = live.latest[0x0D]?.value ?? 0.0;
    final rpm = live.latest[0x0C]?.value ?? 0.0;
    final coolant = live.latest[0x05]?.value;
    final battery = live.latest[0x42]?.value;
    final engineLoad = live.latest[0x04]?.value;
    final maf = live.latest[0x10]?.value;
    final iat = live.latest[0x0F]?.value;
    final throttle = live.latest[0x11]?.value;
    final oilTemp = live.latest[0x5C]?.value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) Top status bar with settings shortcut
              Row(
                children: [
                  Expanded(
                    child: ConnectionStatusBar(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ConnectScreen()),
                      ),
                    ),
                  ),
                  const Gap(8),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: AppColors.cyan,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),

              const Gap(14),

              // 2) Two gauges side by side
              SizedBox(
                height: 230,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _GaugePanel(
                        label: 'SPEED',
                        child: SpeedometerGauge(value: speed),
                      ).animate(delay: 50.ms).fadeIn(duration: 400.ms),
                    ),
                    const Gap(10),
                    Expanded(
                      child: _GaugePanel(
                        label: 'TACHOMETER',
                        child: TachometerGauge(value: rpm),
                      ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                    ),
                  ],
                ),
              ),

              const Gap(12),

              // 3) Car SVG center + side metrics
              SizedBox(
                height: 230,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SideMetricCard(
                        icon: Icons.thermostat_rounded,
                        label: 'ENGINE TEMP',
                        value: coolant?.toStringAsFixed(0),
                        unit: '°C',
                        statusColor: _tempStatus(coolant),
                      ).animate(delay: 150.ms).fadeIn(duration: 400.ms).slideX(
                          begin: -0.15, end: 0),
                    ),
                    const Gap(10),
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('VEHICLE · HEATMAP',
                                    style: AppText.label(size: 9.5)),
                                const Spacer(),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4),
                                child: CarHeatmap(
                                  coolant: coolant,
                                  intakeTemp: iat,
                                  engineLoad: engineLoad,
                                  throttle: throttle,
                                  speed: speed,
                                  oilTemp: oilTemp,
                                ),
                              ),
                            ),
                            _ThrottleBar(
                              value: (throttle ?? 0) / 100,
                            ),
                          ],
                        ),
                      ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                    ),
                    const Gap(10),
                    Expanded(
                      flex: 4,
                      child: SideMetricCard(
                        icon: Icons.battery_charging_full_rounded,
                        label: 'BATTERY',
                        value: battery?.toStringAsFixed(2),
                        unit: 'V',
                        statusColor: _batteryStatus(battery),
                        align: CrossAxisAlignment.end,
                      ).animate(delay: 250.ms).fadeIn(duration: 400.ms).slideX(
                          begin: 0.15, end: 0),
                    ),
                  ],
                ),
              ),

              const Gap(12),

              // 4) Coolant + MAF row
              Row(
                children: [
                  Expanded(
                    child: WideMetricCard(
                      icon: Icons.water_drop_rounded,
                      label: 'COOLANT',
                      value: coolant?.toStringAsFixed(0),
                      unit: '°C',
                      progress: ((coolant ?? 0) / 130).clamp(0.0, 1.0),
                      statusColor: _tempStatus(coolant),
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(
                        begin: 0.2, end: 0),
                  ),
                  const Gap(10),
                  Expanded(
                    child: WideMetricCard(
                      icon: Icons.air_rounded,
                      label: 'MAF SENSOR',
                      value: maf?.toStringAsFixed(1),
                      unit: 'g/s',
                      progress: ((maf ?? 0) / 100).clamp(0.0, 1.0),
                      statusColor: AppColors.cyan,
                    ).animate(delay: 350.ms).fadeIn(duration: 400.ms).slideY(
                        begin: 0.2, end: 0),
                  ),
                ],
              ),

              const Gap(12),

              // Engine load — horizontal mini stat (single accent)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('ENGINE LOAD',
                            style: AppText.label(size: 9.5, letterSpacing: 1.8)),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              engineLoad?.toStringAsFixed(0) ?? '--',
                              style: AppText.digital(
                                  size: 18, color: AppColors.cyan),
                            ),
                            const SizedBox(width: 3),
                            Text('%',
                                style: AppText.body(
                                    size: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    const Gap(10),
                    _SegmentedBar(
                      value: (engineLoad ?? 0) / 100,
                      segments: 24,
                    ),
                  ],
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(
                  begin: 0.2, end: 0),

              const Gap(12),

              // 5) Live chart
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.cyan, blurRadius: 6),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Text('TELEMETRY · LAST 60s',
                            style: AppText.label(size: 10, letterSpacing: 2)),
                        const Spacer(),
                        _LegendDot(color: AppColors.cyan, label: 'RPM'),
                        const Gap(12),
                        _LegendDot(
                            color: AppColors.warn,
                            label: 'TEMP',
                            dashed: true),
                      ],
                    ),
                    const Gap(8),
                    SizedBox(
                      height: 180,
                      child: LiveTelemetryChart(
                        samples: _samples.toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 450.ms).fadeIn(duration: 400.ms).slideY(
                  begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Color _tempStatus(double? c) {
    if (c == null) return AppColors.cyan;
    if (c < 60) return AppColors.cyan;
    if (c < 95) return AppColors.ok;
    if (c < 105) return AppColors.warn;
    return AppColors.danger;
  }

  Color _batteryStatus(double? v) {
    if (v == null) return AppColors.cyan;
    if (v < 11.5) return AppColors.danger;
    if (v < 12.4) return AppColors.warn;
    return AppColors.ok;
  }
}

class _GaugePanel extends StatelessWidget {
  final String label;
  final Widget child;
  const _GaugePanel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(label,
                    style: AppText.label(size: 9.5, letterSpacing: 2)),
                const Spacer(),
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.cyan,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ThrottleBar extends StatelessWidget {
  final double value;
  const _ThrottleBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THROTTLE',
                  style: AppText.label(size: 9, letterSpacing: 1.6)),
              const Spacer(),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: AppText.digital(size: 11, color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: AppColors.surfaceLo),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.cyan.withOpacity(0.5),
                            blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final double value; // 0..1
  final int segments;
  const _SegmentedBar({required this.value, this.segments = 20});

  @override
  Widget build(BuildContext context) {
    final filled = (value * segments).round();
    return Row(
      children: List.generate(segments, (i) {
        final on = i < filled;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: on ? AppColors.cyan : AppColors.surfaceLo,
                borderRadius: BorderRadius.circular(2),
                boxShadow: on
                    ? [
                        BoxShadow(
                            color: AppColors.cyan.withOpacity(0.6),
                            blurRadius: 3),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
          child: dashed
              ? Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.label(size: 9.5, color: color)),
      ],
    );
  }
}
