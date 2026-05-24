import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/live_data_provider.dart';

/// Performance — acceleratie & franare disciplinat.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Timer? _ticker;
  bool _running = false;
  DateTime? _startedAt;

  Duration? _t0to60mph;
  Duration? _t0to100kmh;
  Duration? _t0to200kmh;
  Duration? _quarterMileTime;
  double? _quarterMileTrap;

  bool _braking = false;
  double _brakeStartSpeed = 0;
  double _brakeDistanceM = 0;
  double? _last60to0;
  double? _last100to0;

  double _speed = 0;
  double _lastSpeed = 0;
  double _maxSpeed = 0;
  double _distanceM = 0;
  int _lastTickMs = 0;

  void _startTest() {
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
      _lastTickMs = DateTime.now().millisecondsSinceEpoch;
      _t0to60mph = null;
      _t0to100kmh = null;
      _t0to200kmh = null;
      _quarterMileTime = null;
      _quarterMileTrap = null;
      _maxSpeed = 0;
      _distanceM = 0;
      _braking = false;
      _brakeDistanceM = 0;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  void _stopTest() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _running = false);
  }

  void _tick() {
    if (!mounted || !_running) return;
    final live = context.read<LiveDataProvider>();
    final newSpeed = live.latest[0x0D]?.value ?? 0.0;
    final now = DateTime.now();
    final tMs = now.millisecondsSinceEpoch;
    final dt = ((tMs - _lastTickMs).clamp(1, 5000)) / 1000.0;

    final speedMs = newSpeed / 3.6;
    final dx = speedMs * dt;
    _distanceM += dx;
    if (newSpeed > _maxSpeed) _maxSpeed = newSpeed;

    const ms60 = 60 * 1.609344;
    if (newSpeed >= ms60 && _t0to60mph == null && _startedAt != null) {
      _t0to60mph = now.difference(_startedAt!);
    }
    if (newSpeed >= 100 && _t0to100kmh == null && _startedAt != null) {
      _t0to100kmh = now.difference(_startedAt!);
    }
    if (newSpeed >= 200 && _t0to200kmh == null && _startedAt != null) {
      _t0to200kmh = now.difference(_startedAt!);
    }
    if (_quarterMileTime == null &&
        _distanceM >= 402.336 &&
        _startedAt != null) {
      _quarterMileTime = now.difference(_startedAt!);
      _quarterMileTrap = newSpeed;
    }

    final isDeceleration = newSpeed < _lastSpeed - 0.5;
    if (!_braking && isDeceleration && _lastSpeed >= 60) {
      _braking = true;
      _brakeStartSpeed = _lastSpeed;
      _brakeDistanceM = 0;
    }
    if (_braking) {
      _brakeDistanceM += dx;
      if (newSpeed <= 5) {
        if (_brakeStartSpeed >= 100) {
          _last100to0 = _brakeDistanceM;
        } else if (_brakeStartSpeed >= 60) {
          _last60to0 = _brakeDistanceM;
        }
        _braking = false;
      }
    }

    _lastSpeed = newSpeed;
    _speed = newSpeed;
    _lastTickMs = tMs;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VScaffold(
      appBar: const VAppBar(title: 'Performance'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s16),
              children: [
                _SpeedHero(
                  speed: _speed,
                  maxSpeed: _maxSpeed,
                  distanceM: _distanceM,
                  running: _running,
                  startedAt: _startedAt,
                ),
                const SizedBox(height: VSpace.s12),
                _AccelGrid(
                  t100: _t0to100kmh,
                  t60mph: _t0to60mph,
                  t200: _t0to200kmh,
                  qMile: _quarterMileTime,
                  qTrap: _quarterMileTrap,
                ),
                const SizedBox(height: VSpace.s12),
                _BrakeCard(
                  braking: _braking,
                  last60to0: _last60to0,
                  last100to0: _last100to0,
                  currentBrakeM: _braking ? _brakeDistanceM : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.s16),
            child: _running
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop test'),
                    onPressed: _stopTest,
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start test'),
                    onPressed: _startTest,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────

class _SpeedHero extends StatelessWidget {
  final double speed;
  final double maxSpeed;
  final double distanceM;
  final bool running;
  final DateTime? startedAt;
  const _SpeedHero({
    required this.speed,
    required this.maxSpeed,
    required this.distanceM,
    required this.running,
    required this.startedAt,
  });

  String _fmtElapsed() {
    if (!running || startedAt == null) return '—';
    final secs = DateTime.now().difference(startedAt!).inMilliseconds / 1000.0;
    return secs.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard.hero(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LIVE',
                  style: VType.label11.copyWith(color: t.textMuted)),
              StatusDot(
                status: running ? VStatus.danger : VStatus.neutral,
                pulse: running,
              ),
            ],
          ),
          const SizedBox(height: VSpace.s8),
          Text(
            speed.toStringAsFixed(0),
            style: VType.display72.copyWith(color: t.textStrong),
          ),
          Text('km/h', style: VType.body15.copyWith(color: t.textMuted)),
          const SizedBox(height: VSpace.s16),
          Divider(color: t.hairline, height: 1),
          const SizedBox(height: VSpace.s16),
          Row(
            children: [
              Expanded(
                child: MetricBlock(
                  label: 'Top',
                  value: maxSpeed.toStringAsFixed(0),
                  unit: 'km/h',
                  size: MetricSize.sm,
                ),
              ),
              Container(width: 1, height: 28, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSpace.s8),
                  child: MetricBlock(
                    label: 'Distance',
                    value: distanceM.toStringAsFixed(0),
                    unit: 'm',
                    size: MetricSize.sm,
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: VSpace.s8),
                  child: MetricBlock(
                    label: 'Time',
                    value: _fmtElapsed(),
                    unit: 's',
                    size: MetricSize.sm,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Acceleration result grid
// ─────────────────────────────────────────────────────────────────────

class _AccelGrid extends StatelessWidget {
  final Duration? t100;
  final Duration? t60mph;
  final Duration? t200;
  final Duration? qMile;
  final double? qTrap;

  const _AccelGrid({
    required this.t100,
    required this.t60mph,
    required this.t200,
    required this.qMile,
    required this.qTrap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ResultTile(
            label: '0–100 km/h',
            time: t100,
            icon: Icons.flash_on_rounded,
          ),
        ),
        const SizedBox(width: VSpace.cardGap),
        Expanded(
          child: _ResultTile(
            label: '0–60 mph',
            time: t60mph,
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: VSpace.cardGap),
        Expanded(
          child: _ResultTile(
            label: '0–200',
            time: t200,
            icon: Icons.bolt_rounded,
          ),
        ),
        const SizedBox(width: VSpace.cardGap),
        Expanded(
          child: _ResultTile(
            label: '¼ mile',
            time: qMile,
            trap: qTrap,
            icon: Icons.flag_rounded,
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final Duration? time;
  final IconData icon;
  final double? trap;
  const _ResultTile({
    required this.label,
    required this.time,
    required this.icon,
    this.trap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = time == null
        ? '—'
        : (time!.inMilliseconds / 1000.0).toStringAsFixed(2);
    final hasValue = time != null;
    return VCard(
      padding: const EdgeInsets.all(VSpace.s12),
      child: Column(
        children: [
          Icon(icon, color: t.textMuted, size: 16),
          const SizedBox(height: VSpace.s8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VType.label11.copyWith(color: t.textMuted)),
          const SizedBox(height: VSpace.s4),
          Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VType.title24.copyWith(
              color: hasValue ? t.textStrong : t.textDisabled,
              fontFamily: VType.mono,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('s',
              style: VType.body13.copyWith(color: t.textMuted)),
          if (trap != null) ...[
            const SizedBox(height: VSpace.s4),
            Text('${trap!.toStringAsFixed(0)} km/h',
                style: VType.body13.copyWith(color: t.textDisabled)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Brake card
// ─────────────────────────────────────────────────────────────────────

class _BrakeCard extends StatelessWidget {
  final bool braking;
  final double? last60to0;
  final double? last100to0;
  final double? currentBrakeM;

  const _BrakeCard({
    required this.braking,
    required this.last60to0,
    required this.last100to0,
    required this.currentBrakeM,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fast_rewind_rounded,
                  color: t.textDefault, size: 18),
              const SizedBox(width: VSpace.s8),
              Text('Braking',
                  style: VType.title18.copyWith(color: t.textStrong)),
              const Spacer(),
              if (braking)
                const StatusBadge(
                  label: 'Live',
                  status: VStatus.danger,
                  icon: Icons.fiber_manual_record_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: VSpace.s16),
          Row(
            children: [
              Expanded(
                child: MetricBlock(
                  label: '60–0',
                  value: last60to0?.toStringAsFixed(1),
                  unit: 'm',
                  size: MetricSize.md,
                ),
              ),
              Container(width: 1, height: 32, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSpace.s8),
                  child: MetricBlock(
                    label: '100–0',
                    value: last100to0?.toStringAsFixed(1),
                    unit: 'm',
                    size: MetricSize.md,
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: VSpace.s8),
                  child: MetricBlock(
                    label: 'Current',
                    value: currentBrakeM?.toStringAsFixed(1),
                    unit: 'm',
                    size: MetricSize.md,
                    status: currentBrakeM != null
                        ? VStatus.danger
                        : VStatus.neutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          Text(
            'Initiate braking from at least 60 km/h. '
            'Distance is integrated from speed every 50 ms.',
            style: VType.body13.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
