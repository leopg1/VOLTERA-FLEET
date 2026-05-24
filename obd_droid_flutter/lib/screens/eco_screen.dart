import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/diagnostics_provider.dart';
import '../providers/live_data_provider.dart';

/// Eco driving — focus unic pe scorul 0–100 + 3 sub-metrici de fluiditate.
/// Toate calculele raman; UI-ul devine disciplinat: 1 hero, 1 card de tip,
/// 1 grid smoothness, 1 card stats, 1 RPM bar, 1 readiness block.
class EcoScreen extends StatefulWidget {
  const EcoScreen({super.key});

  @override
  State<EcoScreen> createState() => _EcoScreenState();
}

class _EcoScreenState extends State<EcoScreen> {
  Timer? _ticker;
  final Queue<_Sample> _history = Queue<_Sample>();

  double _fuelLitersTotal = 0;
  double _distanceKmTotal = 0;
  double _lastSpeed = 0;
  int _lastTickMs = 0;

  int _harshAccel = 0;
  int _harshBrake = 0;
  int _idleSeconds = 0;

  String _currentTip = 'Waiting for live data…';

  @override
  void initState() {
    super.initState();
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final live = context.read<LiveDataProvider>();
    final speed = live.latest[0x0D]?.value ?? 0.0;
    final rpm = live.latest[0x0C]?.value ?? 0.0;
    final maf = live.latest[0x10]?.value ?? 0.0;
    final tps = live.latest[0x11]?.value ?? 0.0;
    final load = live.latest[0x04]?.value ?? 0.0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = (now - _lastTickMs).clamp(1, 5000) / 1000.0;
    final accel = ((speed - _lastSpeed) / 3.6) / dt;

    final fuelLs = maf / 14.7 / 750.0;
    _fuelLitersTotal += fuelLs * dt;
    _distanceKmTotal += speed * dt / 3600.0;

    if (accel > 3.5) {
      _harshAccel++;
      HapticFeedback.mediumImpact();
    }
    if (accel < -4.0) {
      _harshBrake++;
      HapticFeedback.heavyImpact();
    }
    if (speed < 1 && rpm > 400) {
      _idleSeconds += dt.round();
    }

    _history.addLast(_Sample(
      tMs: now,
      speed: speed,
      rpm: rpm,
      tps: tps,
      load: load,
      accel: accel,
      maf: maf,
    ));
    final cutoff = now - 60000;
    while (_history.isNotEmpty && _history.first.tMs < cutoff) {
      _history.removeFirst();
    }

    _currentTip = _liveTip();
    _lastSpeed = speed;
    _lastTickMs = now;
    setState(() {});
  }

  // ===== Derived metrics =====

  double get _instantConsumptionL100 {
    if (_history.isEmpty) return 0;
    final last = _history.last;
    if (last.speed < 5) return 0;
    final litersPerHour = (last.maf / 14.7 / 750.0) * 3600.0;
    return litersPerHour / last.speed * 100.0;
  }

  double get _idleFuelLh {
    if (_history.isEmpty) return 0;
    final last = _history.last;
    return (last.maf / 14.7 / 750.0) * 3600.0;
  }

  double get _avgConsumptionL100 {
    if (_distanceKmTotal < 0.05) return 0;
    return _fuelLitersTotal / _distanceKmTotal * 100.0;
  }

  double get _co2Kg => _fuelLitersTotal * 2.31;

  double get _throttleSmoothness {
    if (_history.length < 4) return 1.0;
    double sum = 0;
    int n = 0;
    final list = _history.toList();
    for (var i = 1; i < list.length; i++) {
      sum += (list[i].tps - list[i - 1].tps).abs();
      n++;
    }
    final avgDelta = n > 0 ? sum / n : 0;
    return (1 - (avgDelta / 8).clamp(0.0, 1.0)).toDouble();
  }

  double get _accelSmoothness {
    if (_history.length < 4) return 1.0;
    double max = 0;
    for (final s in _history) {
      final a = s.accel.abs();
      if (a > max) max = a;
    }
    return (1 - (max / 5).clamp(0.0, 1.0)).toDouble();
  }

  double get _rpmZoneScore {
    if (_history.isEmpty) return 1.0;
    int inZone = 0;
    for (final s in _history) {
      if (s.rpm >= 1300 && s.rpm <= 2500) inZone++;
    }
    return inZone / _history.length;
  }

  int get _ecoScore {
    final accel = _accelSmoothness * 100;
    final tps = _throttleSmoothness * 100;
    final rpm = _rpmZoneScore * 100;
    final consPenalty = (_avgConsumptionL100 - 7).clamp(0, 12) * 3;
    final harshPenalty = ((_harshAccel + _harshBrake) * 4).clamp(0, 30);
    final raw = ((accel + tps + rpm) / 3) - consPenalty - harshPenalty;
    return raw.clamp(0, 100).round();
  }

  VStatus get _scoreStatus {
    final s = _ecoScore;
    if (s >= 80) return VStatus.ok;
    if (s >= 60) return VStatus.info;
    if (s >= 40) return VStatus.warn;
    return VStatus.danger;
  }

  String _ecoLabel() {
    final s = _ecoScore;
    if (s >= 90) return 'Eco master';
    if (s >= 80) return 'Excellent';
    if (s >= 60) return 'Good';
    if (s >= 40) return 'Average';
    return 'Aggressive';
  }

  String _liveTip() {
    if (_history.isEmpty) return 'Waiting for live data…';
    final last = _history.last;
    if (last.speed < 1 && _idleSeconds > 30) {
      return 'Idling for a while. Shut off if standing > 1 minute.';
    }
    if (last.rpm > 3500 && last.speed < 80) {
      return 'Shift up — saves fuel and engine wear.';
    }
    if (last.accel > 3.5) {
      return 'Hard acceleration. Press progressively for 10–15% economy.';
    }
    if (last.accel < -4.0) {
      return 'Hard braking. Try to anticipate traffic.';
    }
    if (_throttleSmoothness < 0.5) {
      return 'Throttle oscillates — hold constant pressure.';
    }
    if (last.speed > 130) {
      return 'Above 130 km/h consumption grows exponentially.';
    }
    if (_avgConsumptionL100 > 9) {
      return 'Keep RPM 1500–2500 and a flowing style for best economy.';
    }
    return 'Smooth and efficient. Keep it up.';
  }

  void _resetSession() {
    setState(() {
      _fuelLitersTotal = 0;
      _distanceKmTotal = 0;
      _harshAccel = 0;
      _harshBrake = 0;
      _idleSeconds = 0;
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveDataProvider>();
    final speed = live.latest[0x0D]?.value ?? 0.0;
    final rpm = live.latest[0x0C]?.value ?? 0.0;
    final isMoving = speed >= 5;

    return VScaffold(
      appBar: VAppBar(
        title: 'Eco Driving',
        subtitle: _ecoLabel(),
        actions: [
          IconButton(
            tooltip: 'Reset session',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetSession,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s12, 0, VSpace.s24),
        children: [
          // ─── HERO: eco score arc + consumption sub-stat
          _ScoreHero(
            score: _ecoScore,
            status: _scoreStatus,
            label: _ecoLabel(),
            consumptionLabel: isMoving ? 'L / 100' : 'L / h idle',
            consumptionValue: isMoving
                ? _instantConsumptionL100.toStringAsFixed(1)
                : _idleFuelLh.toStringAsFixed(2),
          ),

          const SizedBox(height: VSpace.s12),

          // ─── Live tip
          _TipCard(tip: _currentTip),

          const SizedBox(height: VSpace.s16),

          // ─── 3 smoothness metrics
          Row(
            children: [
              Expanded(
                child: _SmoothnessCard(
                  icon: Icons.gamepad_rounded,
                  label: 'Throttle',
                  value: _throttleSmoothness,
                ),
              ),
              const SizedBox(width: VSpace.cardGap),
              Expanded(
                child: _SmoothnessCard(
                  icon: Icons.speed_rounded,
                  label: 'Accel',
                  value: _accelSmoothness,
                ),
              ),
              const SizedBox(width: VSpace.cardGap),
              Expanded(
                child: _SmoothnessCard(
                  icon: Icons.electric_bolt_rounded,
                  label: 'RPM zone',
                  value: _rpmZoneScore,
                ),
              ),
            ],
          ),

          const SizedBox(height: VSpace.s16),

          // ─── Session stats
          _SessionStats(
            avgL100: _avgConsumptionL100,
            fuelL: _fuelLitersTotal,
            co2Kg: _co2Kg,
            distanceKm: _distanceKmTotal,
            harshAccel: _harshAccel,
            harshBrake: _harshBrake,
          ),

          const SizedBox(height: VSpace.s16),

          // ─── RPM zone strip
          _RpmZone(rpm: rpm),

          const SizedBox(height: VSpace.s16),

          // ─── Emissions readiness
          const _ReadinessBlock(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero score
// ─────────────────────────────────────────────────────────────────────

class _ScoreHero extends StatelessWidget {
  final int score;
  final VStatus status;
  final String label;
  final String consumptionLabel;
  final String consumptionValue;

  const _ScoreHero({
    required this.score,
    required this.status,
    required this.label,
    required this.consumptionLabel,
    required this.consumptionValue,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard.hero(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LiveArcMeter(
              value: score.toDouble(),
              max: 100,
              label: 'Eco score',
              status: status,
            ),
          ),
          const SizedBox(height: VSpace.s12),
          Divider(color: t.hairline, height: 1),
          const SizedBox(height: VSpace.s16),
          Row(
            children: [
              Expanded(
                child: MetricBlock(
                  label: 'Style',
                  value: label,
                  size: MetricSize.sm,
                  status: status,
                ),
              ),
              Container(width: 1, height: 28, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: VSpace.s16),
                  child: MetricBlock(
                    label: consumptionLabel,
                    value: consumptionValue,
                    size: MetricSize.md,
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
// Tip card
// ─────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      padding: const EdgeInsets.symmetric(
          horizontal: VSpace.s16, vertical: VSpace.s12),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_rounded, color: t.accent, size: 20),
          const SizedBox(width: VSpace.s12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: child,
              ),
              child: Text(
                tip,
                key: ValueKey(tip),
                style: VType.body15.copyWith(color: t.textDefault),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Smoothness card
// ─────────────────────────────────────────────────────────────────────

class _SmoothnessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value; // 0..1
  const _SmoothnessCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  VStatus _statusFor(double v) {
    if (v > 0.7) return VStatus.ok;
    if (v > 0.45) return VStatus.warn;
    return VStatus.danger;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final clamped = value.clamp(0.0, 1.0);
    final status = _statusFor(clamped);
    final color = status.resolve(t);
    final pct = (clamped * 100).round();

    return VCard(
      padding: const EdgeInsets.all(VSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: t.textMuted, size: 16),
              const SizedBox(width: VSpace.s8),
              Expanded(
                child: Text(
                  label,
                  style: VType.label11.copyWith(color: t.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                pct.toString(),
                style: VType.display40.copyWith(
                  color: color,
                  fontFamily: VType.mono,
                  fontWeight: FontWeight.w600,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 2),
              Text('%',
                  style: VType.body13.copyWith(color: t.textMuted)),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 3,
              backgroundColor: t.canvas,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Session stats
// ─────────────────────────────────────────────────────────────────────

class _SessionStats extends StatelessWidget {
  final double avgL100;
  final double fuelL;
  final double co2Kg;
  final double distanceKm;
  final int harshAccel;
  final int harshBrake;

  const _SessionStats({
    required this.avgL100,
    required this.fuelL,
    required this.co2Kg,
    required this.distanceKm,
    required this.harshAccel,
    required this.harshBrake,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                VSpace.s20, VSpace.s16, VSpace.s20, VSpace.s8),
            child: Text(
              'Session statistics',
              style: VType.title18.copyWith(color: t.textStrong),
            ),
          ),
          ValueRow(
            label: 'Avg consumption',
            value: avgL100.toStringAsFixed(1),
            unit: 'L/100',
            leadingIcon: Icons.local_gas_station_rounded,
          ),
          ValueRow(
            label: 'Fuel used',
            value: fuelL.toStringAsFixed(2),
            unit: 'L',
            leadingIcon: Icons.opacity_rounded,
          ),
          ValueRow(
            label: 'CO₂ emitted',
            value: co2Kg.toStringAsFixed(2),
            unit: 'kg',
            leadingIcon: Icons.cloud_outlined,
          ),
          ValueRow(
            label: 'Distance',
            value: distanceKm.toStringAsFixed(2),
            unit: 'km',
            leadingIcon: Icons.straighten_rounded,
          ),
          ValueRow(
            label: 'Harsh accel events',
            value: harshAccel.toString(),
            leadingIcon: Icons.fast_forward_rounded,
            trailing: harshAccel > 0
                ? StatusBadge(
                    label: harshAccel.toString(),
                    status: VStatus.warn,
                    dense: true,
                  )
                : null,
          ),
          ValueRow(
            label: 'Harsh brake events',
            value: harshBrake.toString(),
            leadingIcon: Icons.fast_rewind_rounded,
            divider: false,
            trailing: harshBrake > 0
                ? StatusBadge(
                    label: harshBrake.toString(),
                    status: VStatus.danger,
                    dense: true,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// RPM zone strip
// ─────────────────────────────────────────────────────────────────────

class _RpmZone extends StatelessWidget {
  final double rpm;
  const _RpmZone({required this.rpm});

  bool get _inZone => rpm >= 1300 && rpm <= 2500;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('RPM zone',
                  style: VType.title18.copyWith(color: t.textStrong)),
              const Spacer(),
              Text(
                rpm.toStringAsFixed(0),
                style: VType.mono15.copyWith(
                  color: _inZone ? t.ok : t.warn,
                ),
              ),
              const SizedBox(width: VSpace.s4),
              Text('rpm', style: VType.body13.copyWith(color: t.textMuted)),
            ],
          ),
          const SizedBox(height: VSpace.s16),
          SizedBox(
            height: 8,
            child: LayoutBuilder(builder: (_, c) {
              const maxRpm = 7000.0;
              final pos = (rpm / maxRpm).clamp(0.0, 1.0) * c.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Zonele: 0-1300 muted, 1300-2500 ok, 2500-4500 info, 4500-7000 warn
                  Row(
                    children: [
                      Expanded(
                        flex: 1300,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1200,
                        child: Container(color: t.ok.withValues(alpha: 0.5)),
                      ),
                      Expanded(
                        flex: 2000,
                        child: Container(color: t.warn.withValues(alpha: 0.45)),
                      ),
                      Expanded(
                        flex: 2500,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.danger.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: pos - 1,
                    top: -3,
                    bottom: -3,
                    child: Container(
                      width: 2,
                      color: t.textStrong,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: VSpace.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Eco 1.3–2.5k',
                  style: VType.body13.copyWith(color: t.textMuted)),
              Text('Redline 6.5k',
                  style: VType.body13.copyWith(color: t.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Emissions readiness
// ─────────────────────────────────────────────────────────────────────

class _ReadinessBlock extends StatelessWidget {
  const _ReadinessBlock();

  @override
  Widget build(BuildContext context) {
    final diag = context.watch<DiagnosticsProvider>();
    final t = context.tokens;
    final hasMil = diag.hasMil;
    final overall = hasMil ? VStatus.danger : VStatus.ok;

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Emissions readiness',
                  style: VType.title18.copyWith(color: t.textStrong)),
              const Spacer(),
              StatusBadge(
                label: hasMil ? 'Fail' : 'Pass',
                status: overall,
                icon: hasMil ? Icons.error_outline_rounded : Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: VSpace.s16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: VSpace.s8,
            crossAxisSpacing: VSpace.s8,
            childAspectRatio: 4.2,
            children: [
              _miniMon(context, 'Misfire', !hasMil),
              _miniMon(context, 'Fuel system', true),
              _miniMon(context, 'Components', true),
              _miniMon(context, 'Catalyst', !hasMil),
              _miniMon(context, 'O₂ sensor', true),
              _miniMon(context, 'O₂ heater', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMon(BuildContext context, String label, bool ready) {
    final t = context.tokens;
    final status = ready ? VStatus.ok : VStatus.danger;
    return Row(
      children: [
        StatusDot(status: status),
        const SizedBox(width: VSpace.s8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VType.body13.copyWith(color: t.textDefault),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sample model (private)
// ─────────────────────────────────────────────────────────────────────

class _Sample {
  final int tMs;
  final double speed;
  final double rpm;
  final double tps;
  final double load;
  final double accel;
  final double maf;
  const _Sample({
    required this.tMs,
    required this.speed,
    required this.rpm,
    required this.tps,
    required this.load,
    required this.accel,
    required this.maf,
  });
}
