import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../providers/diagnostics_provider.dart';
import '../providers/live_data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_card.dart';

/// Smart eco-driving screen.
///
/// Combines:
///  - Live consumption (instant + average) computed from MAF + speed
///  - Eco score (0–100) from RPM zones, accel smoothness, throttle aggressiveness
///  - Driving smoothness rings (acceleration, throttle, RPM zone)
///  - CO₂ estimate, fuel saved-vs-baseline
///  - Tips engine that updates with current driving
///  - I/M readiness summary (rolled into "tehnica" row at bottom)
class EcoScreen extends StatefulWidget {
  const EcoScreen({super.key});

  @override
  State<EcoScreen> createState() => _EcoScreenState();
}

class _EcoScreenState extends State<EcoScreen> {
  Timer? _ticker;

  // Rolling history for smoothness analysis (~last 60s).
  final Queue<_Sample> _history = Queue<_Sample>();

  // Aggregates
  double _fuelLitersTotal = 0;
  double _distanceKmTotal = 0;
  double _lastSpeed = 0;
  int _lastTickMs = 0;

  // Smoothness counters
  int _harshAccel = 0;
  int _harshBrake = 0;
  int _idleSeconds = 0;

  // Eco score timeline pentru sparkline (ultimele ~60 mostre = 30s la 500ms).
  final Queue<int> _scoreHistory = Queue<int>();

  // Pentru animatia tip-ului
  String _currentTip = 'Astept date OBD live...';

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

    // Fuel via MAF / 14.7 / 750 = L/s
    final fuelLs = maf / 14.7 / 750.0;
    _fuelLitersTotal += fuelLs * dt;
    _distanceKmTotal += speed * dt / 3600.0;

    final wasAccel = accel > 3.5;
    final wasBrake = accel < -4.0;
    if (wasAccel) {
      _harshAccel++;
      HapticFeedback.mediumImpact();
    }
    if (wasBrake) {
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

    // Snapshot score pentru sparkline.
    _scoreHistory.addLast(_ecoScore);
    while (_scoreHistory.length > 60) {
      _scoreHistory.removeFirst();
    }

    // Recalculam tip-ul si lasam AnimatedSwitcher sa-l interpoleze.
    final nextTip = _liveTip();
    if (nextTip != _currentTip) {
      _currentTip = nextTip;
    }

    _lastSpeed = speed;
    _lastTickMs = now;
    setState(() {});
  }

  // ===== Derived metrics =====

  double get _instantConsumptionL100 {
    if (_history.isEmpty) return 0;
    final last = _history.last;
    if (last.speed < 5) {
      // At idle, show fuel rate in L/h equivalent (rendered separately by UI)
      return 0;
    }
    final fuelLs = last.maf / 14.7 / 750.0;
    final litersPerHour = fuelLs * 3600.0;
    return litersPerHour / last.speed * 100.0;
  }

  double get _idleFuelLh {
    if (_history.isEmpty) return 0;
    final last = _history.last;
    final fuelLs = last.maf / 14.7 / 750.0;
    return fuelLs * 3600.0;
  }

  double get _avgConsumptionL100 {
    if (_distanceKmTotal < 0.05) return 0;
    return _fuelLitersTotal / _distanceKmTotal * 100.0;
  }

  double get _co2Kg => _fuelLitersTotal * 2.31;

  /// Smoothness ring 0..1 — penalizes large deltas in throttle.
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
    final score = (1 - (avgDelta / 8).clamp(0.0, 1.0));
    return score.toDouble();
  }

  /// Acceleration smoothness 0..1.
  double get _accelSmoothness {
    if (_history.length < 4) return 1.0;
    double max = 0;
    for (final s in _history) {
      final a = s.accel.abs();
      if (a > max) max = a;
    }
    final score = (1 - (max / 5).clamp(0.0, 1.0));
    return score.toDouble();
  }

  /// RPM-zone score: stays close to ideal cruise band.
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
    final consPenalty =
        (_avgConsumptionL100 - 7).clamp(0, 12) * 3;
    final harshPenalty = ((_harshAccel + _harshBrake) * 4).clamp(0, 30);
    final raw = ((accel + tps + rpm) / 3) - consPenalty - harshPenalty;
    return raw.clamp(0, 100).round();
  }

  Color get _scoreColor {
    final s = _ecoScore;
    if (s >= 80) return AppColors.ok;
    if (s >= 60) return AppColors.cyan;
    if (s >= 40) return AppColors.warn;
    return AppColors.danger;
  }

  String _ecoLabel() {
    final s = _ecoScore;
    if (s >= 90) return 'ECO MASTER';
    if (s >= 80) return 'EXCELENT';
    if (s >= 60) return 'BUN';
    if (s >= 40) return 'MEDIU';
    return 'AGRESIV';
  }

  String _liveTip() {
    if (_history.isEmpty) return 'Astept date OBD live...';
    final last = _history.last;
    if (last.speed < 1 && _idleSeconds > 30) {
      return 'Idling de mult. Opreste motorul daca stai > 1 minut.';
    }
    if (last.rpm > 3500 && last.speed < 80) {
      return 'Schimba intr-o treapta superioara — economisesti combustibil.';
    }
    if (last.accel > 3.5) {
      return 'Accelerare brutala. Apasa progresiv pentru 10-15% economie.';
    }
    if (last.accel < -4.0) {
      return 'Franare brusca. Anticipeaza traficul.';
    }
    if (_throttleSmoothness < 0.5) {
      return 'Pedala oscileaza prea mult — mentine apasare constanta.';
    }
    if (last.speed > 130) {
      return 'Peste 130 km/h consumul creste exponential.';
    }
    if (_avgConsumptionL100 > 9) {
      return 'Mentine RPM 1500-2500 si stil cursiv pentru economie maxima.';
    }
    return 'Mers fluid si eficient. Continua tot asa.';
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco_rounded,
                      color: AppColors.ok, size: 22),
                  const Gap(8),
                  Text('ECO DRIVING',
                      style: AppText.label(
                          size: 13,
                          color: AppColors.ok,
                          weight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                    onPressed: _resetSession,
                    tooltip: 'Reset sesiune',
                    icon: const Icon(Icons.restart_alt_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              const Gap(12),

              // Eco score hero + live consumption
              NeonCard(
                showGlow: true,
                glow: _scoreColor,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: _ecoScore / 100,
                              strokeWidth: 8,
                              backgroundColor: AppColors.surfaceHi,
                              valueColor: AlwaysStoppedAnimation(_scoreColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_ecoScore.toString(),
                                  style: AppText.digital(
                                      size: 30,
                                      color: _scoreColor,
                                      weight: FontWeight.w900)),
                              Text('SCORE',
                                  style: AppText.label(
                                      size: 8,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_ecoLabel(),
                              style: AppText.title(
                                  size: 18, color: _scoreColor)),
                          const Gap(2),
                          Text('STIL DE CONDUS',
                              style: AppText.label(size: 9.5)),
                          const Gap(8),
                          // Sparkline ultimele scoruri eco — trend la o privire.
                          SizedBox(
                            height: 22,
                            child: CustomPaint(
                              painter: _ScoreSparkline(
                                values: _scoreHistory.toList(),
                                color: _scoreColor,
                              ),
                              size: const Size(double.infinity, 22),
                            ),
                          ),
                          const Gap(6),
                          if (isMoving)
                            _bigConsumption(
                              label: 'CONSUM',
                              value: _instantConsumptionL100
                                  .toStringAsFixed(1),
                              unit: 'L/100',
                            )
                          else
                            _bigConsumption(
                              label: 'IDLE',
                              value: _idleFuelLh.toStringAsFixed(2),
                              unit: 'L/h',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),

              const Gap(12),

              // Live tip card cu tranzitie animata intre mesaje
              NeonCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded,
                        color: AppColors.cyan, size: 22),
                    const Gap(10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _currentTip,
                          key: ValueKey(_currentTip),
                          style: AppText.body(size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 350.ms),

              const Gap(12),

              // Smoothness rings: throttle, accel, rpm zone
              Row(
                children: [
                  Expanded(
                    child: _SmoothnessRing(
                      label: 'THROTTLE',
                      value: _throttleSmoothness,
                      icon: Icons.gamepad_rounded,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _SmoothnessRing(
                      label: 'ACCEL',
                      value: _accelSmoothness,
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _SmoothnessRing(
                      label: 'RPM ZONE',
                      value: _rpmZoneScore,
                      icon: Icons.electric_bolt_rounded,
                    ),
                  ),
                ],
              ).animate(delay: 200.ms).fadeIn(),

              const Gap(12),

              // Stats row
              NeonCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STATISTICI SESIUNE',
                        style: AppText.label(size: 10)),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: _statTile(
                            'AVG L/100',
                            _avgConsumptionL100.toStringAsFixed(1),
                            AppColors.cyan,
                            Icons.local_gas_station_rounded,
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _statTile(
                            'COMBUSTIBIL',
                            _fuelLitersTotal.toStringAsFixed(2),
                            AppColors.warn,
                            Icons.opacity_rounded,
                            unit: 'L',
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _statTile(
                            'CO₂',
                            _co2Kg.toStringAsFixed(2),
                            AppColors.ok,
                            Icons.cloud_outlined,
                            unit: 'kg',
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _statTile(
                            'DIST',
                            _distanceKmTotal.toStringAsFixed(2),
                            AppColors.cyan,
                            Icons.straighten_rounded,
                            unit: 'km',
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _statTile(
                            'HARSH+',
                            _harshAccel.toString(),
                            AppColors.warn,
                            Icons.fast_forward_rounded,
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _statTile(
                            'HARSH-',
                            _harshBrake.toString(),
                            AppColors.danger,
                            Icons.fast_rewind_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate(delay: 250.ms).fadeIn(),

              const Gap(12),

              // RPM bar with eco zones
              NeonCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('RPM ZONE',
                            style: AppText.label(size: 10)),
                        const Spacer(),
                        Text(
                          '${rpm.toStringAsFixed(0)} rpm',
                          style: AppText.digital(
                              size: 14,
                              color: _rpmInZone(rpm)
                                  ? AppColors.ok
                                  : AppColors.warn),
                        ),
                      ],
                    ),
                    const Gap(10),
                    SizedBox(
                      height: 18,
                      child: LayoutBuilder(builder: (_, c) {
                        const maxRpm = 7000.0;
                        final pos = (rpm / maxRpm).clamp(0.0, 1.0) * c.maxWidth;
                        return Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.cyan,
                                    AppColors.ok,
                                    AppColors.warn,
                                    AppColors.danger,
                                  ],
                                  stops: [0.0, 0.36, 0.6, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Positioned(
                              left: pos - 1.5,
                              top: -2,
                              bottom: -2,
                              child: Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.white60,
                                        blurRadius: 4)
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const Gap(6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ECO 1300-2500',
                            style: AppText.label(
                                size: 9, color: AppColors.ok)),
                        Text('REDLINE 6500',
                            style: AppText.label(
                                size: 9, color: AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ).animate(delay: 300.ms).fadeIn(),

              const Gap(12),

              // Emissions readiness summary
              const _ReadinessBlock(),
            ],
          ),
        ),
      ),
    );
  }

  bool _rpmInZone(double rpm) => rpm >= 1300 && rpm <= 2500;

  Widget _bigConsumption(
      {required String label, required String value, required String unit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(size: 9.5)),
        const Gap(2),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: value,
              style: AppText.digital(
                  size: 26,
                  color: _scoreColor,
                  weight: FontWeight.w900),
            ),
            TextSpan(
              text: ' $unit',
              style: AppText.body(size: 11, color: AppColors.textMuted),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon,
      {String? unit}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const Gap(4),
              Expanded(
                child: Text(
                  label,
                  style: AppText.label(size: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(6),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: AppText.digital(
                    size: 17,
                    color: color,
                    weight: FontWeight.w900),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: AppText.body(size: 9, color: AppColors.textMuted),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

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

class _SmoothnessRing extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  const _SmoothnessRing({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final color = clamped > 0.7
        ? AppColors.ok
        : clamped > 0.45
            ? AppColors.warn
            : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: clamped,
                    strokeWidth: 5,
                    backgroundColor: AppColors.surfaceHi,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
          ),
          const Gap(8),
          Text(label,
              style: AppText.label(size: 9, color: AppColors.textMuted)),
          const Gap(2),
          Text('${(clamped * 100).round()}%',
              style: AppText.digital(size: 14, color: color)),
        ],
      ),
    );
  }
}

/// Sparkline minimalist: deseneaza o linie cu evolutia scorului eco
/// in ultimele ~30 secunde. Util ca trend la o privire.
class _ScoreSparkline extends CustomPainter {
  final List<int> values;
  final Color color;
  _ScoreSparkline({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0, 100);
      final y = size.height - (v / 100.0) * size.height;
      final x = i * dx;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(_ScoreSparkline old) =>
      old.values.length != values.length ||
      (values.isNotEmpty && old.values.lastOrNull != values.lastOrNull) ||
      old.color != color;
}

class _ReadinessBlock extends StatelessWidget {
  const _ReadinessBlock();

  @override
  Widget build(BuildContext context) {
    final diag = context.watch<DiagnosticsProvider>();
    final hasMil = diag.hasMil;
    return NeonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMil ? Icons.error_outline_rounded : Icons.verified_rounded,
                color: hasMil ? AppColors.danger : AppColors.ok,
                size: 18,
              ),
              const Gap(8),
              Text('EMISSIONS READINESS', style: AppText.label(size: 10)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasMil ? AppColors.danger : AppColors.ok)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (hasMil ? AppColors.danger : AppColors.ok)
                        .withOpacity(0.4),
                  ),
                ),
                child: Text(
                  hasMil ? 'FAIL' : 'PASS',
                  style: AppText.label(
                    size: 10,
                    color: hasMil ? AppColors.danger : AppColors.ok,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Gap(10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.4,
            children: [
              _miniMon('Misfire', !hasMil, Icons.flash_on_rounded),
              _miniMon('Fuel System', true, Icons.local_gas_station_rounded),
              _miniMon('Components', true, Icons.memory_rounded),
              _miniMon('Catalyst', !hasMil, Icons.science_rounded),
              _miniMon('O2 Sensor', true, Icons.opacity_rounded),
              _miniMon('O2 Heater', true, Icons.whatshot_rounded),
            ],
          ),
        ],
      ),
    ).animate(delay: 350.ms).fadeIn();
  }

  Widget _miniMon(String label, bool ready, IconData icon) {
    final color = ready ? AppColors.ok : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 13),
          const Gap(6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(size: 9.5, color: color),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
