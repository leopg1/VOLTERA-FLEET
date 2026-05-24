import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/connection_state.dart';
import '../design/design.dart';
import '../features/connect/connect_screen.dart';
import '../providers/connection_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/vehicle_provider.dart';
import 'settings_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TelemetrySample {
  final DateTime t;
  final double rpm;
  final double engineTemp;
  TelemetrySample(this.t, this.rpm, this.engineTemp);
}

/// Dashboard — focus: stare instanta a vehiculului in 0.5s.
/// Hero: speed + live arc meter. Sub-hero: 2x2 MetricBlock. Card unic chart 60s.
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
    final throttle = live.latest[0x11]?.value;

    return VScaffold(
      appBar: VAppBar(
        title: 'Dashboard',
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, VSpace.s12, 0, VSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) Status pill (single row, no decoration)
              const _ConnectionRow(),

              const SizedBox(height: VSpace.s20),

              // 2) Hero — Speed with live arc
              _SpeedHero(speed: speed, rpm: rpm),

              const SizedBox(height: VSpace.s16),

              // 3) Secondary metrics — 2x2 grid
              _SecondaryGrid(
                coolant: coolant,
                battery: battery,
                engineLoad: engineLoad,
                throttle: throttle,
              ),

              const SizedBox(height: VSpace.s16),

              // 4) Telemetry chart — single series RPM, last 60s
              _TelemetryCard(samples: _samples.toList(growable: false)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Connection row
// ─────────────────────────────────────────────────────────────────────

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow();

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final vehicle = context.watch<VehicleProvider>().vehicle;
    final s = conn.state;
    final (label, status, meta, pulse) = _statusMap(s, conn, vehicle?.displayName);

    return ConnectionPill(
      label: label,
      meta: meta,
      status: status,
      pulse: pulse,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
      ),
    );
  }

  (String, VStatus, String?, bool) _statusMap(
    ObdLinkState s,
    ConnectionProvider conn,
    String? vehicleName,
  ) {
    final adapterName = conn.activeAdapter?.name;
    final meta = vehicleName ?? adapterName;
    switch (s) {
      case ObdLinkState.disconnected:
        return ('Offline', VStatus.neutral, 'Tap to connect', false);
      case ObdLinkState.scanning:
        return ('Scanning', VStatus.warn, meta, true);
      case ObdLinkState.connecting:
        return ('Linking', VStatus.warn, meta, true);
      case ObdLinkState.initializing:
        return ('Initializing', VStatus.warn, meta, true);
      case ObdLinkState.ready:
        return ('Live', VStatus.ok, meta, true);
      case ObdLinkState.busy:
        return ('Busy', VStatus.info, meta, false);
      case ObdLinkState.error:
        return ('Error', VStatus.danger, meta, false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Speed hero card
// ─────────────────────────────────────────────────────────────────────

class _SpeedHero extends StatelessWidget {
  final double speed;
  final double rpm;
  const _SpeedHero({required this.speed, required this.rpm});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard.hero(
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: LiveArcMeter(
              value: speed,
              max: 240,
              label: 'Speed',
              unit: 'km/h',
              status: VStatus.info,
            ),
          ),
          const SizedBox(height: VSpace.s12),
          Divider(color: t.hairline, height: 1),
          const SizedBox(height: VSpace.s16),
          Row(
            children: [
              Expanded(
                child: MetricBlock(
                  label: 'RPM',
                  value: rpm.toStringAsFixed(0),
                  unit: 'rpm',
                  size: MetricSize.md,
                ),
              ),
              Container(width: 1, height: 28, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: VSpace.s16),
                  child: MetricBlock(
                    label: 'Eco score',
                    value: _ecoFromSpeedRpm(speed, rpm).toStringAsFixed(0),
                    unit: '/100',
                    size: MetricSize.md,
                    status: _ecoFromSpeedRpm(speed, rpm) >= 70
                        ? VStatus.ok
                        : (_ecoFromSpeedRpm(speed, rpm) >= 40
                            ? VStatus.warn
                            : VStatus.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Heuristic minor — scopul e doar un signal calm pe hero.
  // Eco score real se calculeaza in EcoProvider.
  int _ecoFromSpeedRpm(double speed, double rpm) {
    if (speed <= 0) return 100;
    final eff = (speed / (rpm.clamp(800, 6000) / 1000));
    return (eff * 6).clamp(0, 100).round();
  }
}

// ─────────────────────────────────────────────────────────────────────
// 2x2 secondary metric grid
// ─────────────────────────────────────────────────────────────────────

class _SecondaryGrid extends StatelessWidget {
  final double? coolant;
  final double? battery;
  final double? engineLoad;
  final double? throttle;

  const _SecondaryGrid({
    required this.coolant,
    required this.battery,
    required this.engineLoad,
    required this.throttle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Coolant',
                  value: coolant?.toStringAsFixed(0),
                  unit: '°C',
                  size: MetricSize.lg,
                  status: _coolantStatus(coolant),
                  leadingIcon: Icons.thermostat_rounded,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Battery',
                  value: battery?.toStringAsFixed(1),
                  unit: 'V',
                  size: MetricSize.lg,
                  status: _batteryStatus(battery),
                  leadingIcon: Icons.battery_charging_full_rounded,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: VSpace.cardGap),
        Row(
          children: [
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Engine load',
                  value: engineLoad?.toStringAsFixed(0),
                  unit: '%',
                  size: MetricSize.lg,
                  leadingIcon: Icons.bolt_rounded,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Throttle',
                  value: throttle?.toStringAsFixed(0),
                  unit: '%',
                  size: MetricSize.lg,
                  leadingIcon: Icons.speed_rounded,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  VStatus _coolantStatus(double? c) {
    if (c == null) return VStatus.neutral;
    if (c < 60) return VStatus.info;
    if (c < 95) return VStatus.ok;
    if (c < 105) return VStatus.warn;
    return VStatus.danger;
  }

  VStatus _batteryStatus(double? v) {
    if (v == null) return VStatus.neutral;
    if (v < 11.5) return VStatus.danger;
    if (v < 12.4) return VStatus.warn;
    return VStatus.ok;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Telemetry chart — single accent series, no glow
// ─────────────────────────────────────────────────────────────────────

class _TelemetryCard extends StatelessWidget {
  final List<TelemetrySample> samples;
  const _TelemetryCard({required this.samples});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      padding: const EdgeInsets.all(VSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Engine RPM',
                        style: VType.title18.copyWith(color: t.textStrong)),
                    const SizedBox(height: 2),
                    Text('Last 60 seconds',
                        style: VType.body13.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'LIVE',
                status: VStatus.info,
                icon: Icons.fiber_manual_record_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: VSpace.s16),
          SizedBox(
            height: 160,
            child: _RpmChart(samples: samples),
          ),
        ],
      ),
    );
  }
}

class _RpmChart extends StatelessWidget {
  final List<TelemetrySample> samples;
  const _RpmChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final start = now.subtract(const Duration(seconds: 60));

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      plotAreaBackgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      primaryXAxis: DateTimeAxis(
        minimum: start,
        maximum: now,
        majorGridLines: MajorGridLines(width: 0.5, color: t.hairline),
        majorTickLines: const MajorTickLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: VType.label11.copyWith(color: t.textDisabled),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 8000,
        interval: 2000,
        majorGridLines: MajorGridLines(width: 0.5, color: t.hairline),
        majorTickLines: const MajorTickLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: VType.label11.copyWith(color: t.textDisabled),
      ),
      series: <CartesianSeries<TelemetrySample, DateTime>>[
        FastLineSeries<TelemetrySample, DateTime>(
          name: 'RPM',
          dataSource: samples,
          xValueMapper: (s, _) => s.t,
          yValueMapper: (s, _) => s.rpm,
          color: t.accent,
          width: 1.5,
        ),
      ],
    );
  }
}
