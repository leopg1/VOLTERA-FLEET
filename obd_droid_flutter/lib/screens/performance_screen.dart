import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../providers/live_data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_card.dart';
import '../widgets/racing_button.dart';

/// Performance test suite — captures classic acceleration / braking
/// benchmarks live during a session: 0-60mph, 0-100km/h, quarter-mile time
/// & terminal speed, 60-0 braking distance and personal-best logging.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Timer? _ticker;
  bool _running = false;
  DateTime? _startedAt;

  // Acceleration metrics
  Duration? _t0to60mph;
  Duration? _t0to100kmh;
  Duration? _t0to200kmh;
  Duration? _quarterMileTime;
  double? _quarterMileTrap;

  // Braking metrics
  bool _braking = false;
  DateTime? _brakeStart;
  double _brakeStartSpeed = 0;
  double _brakeDistanceM = 0;
  double? _last60to0;
  double? _last100to0;

  // Tracking
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
      _brakeStart = null;
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

    // Acceleration milestones
    final ms60 = 60 * 1.609344;
    if (newSpeed >= ms60 && _t0to60mph == null && _startedAt != null) {
      _t0to60mph = now.difference(_startedAt!);
    }
    if (newSpeed >= 100 && _t0to100kmh == null && _startedAt != null) {
      _t0to100kmh = now.difference(_startedAt!);
    }
    if (newSpeed >= 200 && _t0to200kmh == null && _startedAt != null) {
      _t0to200kmh = now.difference(_startedAt!);
    }

    // Quarter mile = 402.336m
    if (_quarterMileTime == null && _distanceM >= 402.336 && _startedAt != null) {
      _quarterMileTime = now.difference(_startedAt!);
      _quarterMileTrap = newSpeed;
    }

    // Brake start detection — was decelerating now hard
    final isDeceleration = newSpeed < _lastSpeed - 0.5;
    if (!_braking && isDeceleration && _lastSpeed >= 60) {
      _braking = true;
      _brakeStart = now;
      _brakeStartSpeed = _lastSpeed;
      _brakeDistanceM = 0;
    }
    if (_braking) {
      _brakeDistanceM += dx;
      if (newSpeed <= 5) {
        // Brake event ended.
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
    return Scaffold(
      appBar:
          AppBar(title: Text('PERFORMANCE', style: AppText.title(size: 16))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _heroCard(),
                      const Gap(12),
                      _accelGrid(),
                      const Gap(12),
                      _brakeCard(),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              RacingButton(
                label: _running ? 'STOP TEST' : 'START TEST',
                icon: _running
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                color: _running ? AppColors.danger : AppColors.cyan,
                isOn: _running,
                onPressed: _running ? _stopTest : _startTest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return NeonCard(
      showGlow: true,
      glow: AppColors.warn,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LIVE', style: AppText.label(size: 10)),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _running ? AppColors.danger : AppColors.textDim,
                  shape: BoxShape.circle,
                  boxShadow: _running
                      ? [
                          const BoxShadow(
                              color: AppColors.danger, blurRadius: 6)
                        ]
                      : null,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            _speed.toStringAsFixed(0),
            style: AppText.digital(
                size: 80, color: AppColors.cyan, weight: FontWeight.w900),
          ),
          Text('km/h',
              style:
                  AppText.label(size: 11, color: AppColors.textMuted)),
          const Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _heroStat('MAX', _maxSpeed.toStringAsFixed(0), 'km/h'),
              _heroStat('DIST', _distanceM.toStringAsFixed(0), 'm'),
              _heroStat(
                'TIMP',
                _running && _startedAt != null
                    ? _fmtDuration(DateTime.now().difference(_startedAt!))
                    : '—',
                's',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _heroStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: AppText.label(size: 9)),
        const Gap(2),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: value,
                style: AppText.digital(size: 16, color: AppColors.cyan)),
            TextSpan(
                text: ' $unit',
                style: AppText.body(size: 9, color: AppColors.textMuted)),
          ]),
        ),
      ],
    );
  }

  Widget _accelGrid() {
    return Row(
      children: [
        Expanded(
          child: _resultTile(
            label: '0-100 km/h',
            time: _t0to100kmh,
            color: AppColors.cyan,
            icon: Icons.flash_on_rounded,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _resultTile(
            label: '0-60 mph',
            time: _t0to60mph,
            color: AppColors.cyan,
            icon: Icons.speed_rounded,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _resultTile(
            label: '0-200',
            time: _t0to200kmh,
            color: AppColors.warn,
            icon: Icons.bolt_rounded,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _resultTile(
            label: '1/4 MI',
            time: _quarterMileTime,
            trap: _quarterMileTrap,
            color: AppColors.warn,
            icon: Icons.flag_rounded,
          ),
        ),
      ],
    );
  }

  Widget _resultTile({
    required String label,
    required Duration? time,
    required Color color,
    required IconData icon,
    double? trap,
  }) {
    final v = time == null
        ? '— —'
        : (time.inMilliseconds / 1000.0).toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const Gap(6),
          Text(label, style: AppText.label(size: 9)),
          const Gap(4),
          Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.digital(
                  size: 16, color: color, weight: FontWeight.w900)),
          Text('s', style: AppText.label(size: 8)),
          if (trap != null) ...[
            const Gap(4),
            Text('${trap.toStringAsFixed(0)} km/h',
                style: AppText.label(
                    size: 8.5, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _brakeCard() {
    return NeonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fast_rewind_rounded,
                  color: AppColors.danger, size: 18),
              const Gap(8),
              Text('BRAKING', style: AppText.label(size: 10)),
              const Spacer(),
              if (_braking)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('LIVE',
                      style: AppText.label(
                          size: 9, color: AppColors.danger)),
                ),
            ],
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: _kvBig(
                  label: '60-0 km/h',
                  value: _last60to0?.toStringAsFixed(1) ?? '— —',
                  unit: 'm',
                  color: AppColors.cyan,
                ),
              ),
              Expanded(
                child: _kvBig(
                  label: '100-0 km/h',
                  value: _last100to0?.toStringAsFixed(1) ?? '— —',
                  unit: 'm',
                  color: AppColors.warn,
                ),
              ),
              Expanded(
                child: _kvBig(
                  label: 'CURRENT',
                  value: _braking
                      ? _brakeDistanceM.toStringAsFixed(1)
                      : '— —',
                  unit: 'm',
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Initiaza franarea de la viteza minima 60 km/h. '
            'Distanta este integrata din viteza · 50 ms tick.',
            style: AppText.body(size: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _kvBig(
      {required String label,
      required String value,
      required String unit,
      required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(size: 9)),
          const Gap(2),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: value,
                  style: AppText.digital(
                      size: 17, color: color, weight: FontWeight.w900)),
              TextSpan(
                  text: ' $unit',
                  style:
                      AppText.body(size: 9, color: AppColors.textMuted)),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final secs = d.inMilliseconds / 1000.0;
    return secs.toStringAsFixed(2);
  }
}
