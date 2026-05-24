import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/location_service.dart';
import '../providers/live_data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_card.dart';
import '../widgets/racing_button.dart';

/// O sesiune Track inregistrata: agregate (peak speed, peak RPM, 0-100) +
/// lista de lap-uri. Salvata in SharedPreferences pentru istoric demo.
class _TrackSession {
  final DateTime startedAt;
  final Duration totalDuration;
  final Duration? zeroTo100;
  final double maxSpeedKmh;
  final double maxRpm;
  final double maxG;
  final List<Duration> laps;
  final bool gpsUsed;

  _TrackSession({
    required this.startedAt,
    required this.totalDuration,
    required this.zeroTo100,
    required this.maxSpeedKmh,
    required this.maxRpm,
    required this.maxG,
    required this.laps,
    required this.gpsUsed,
  });

  Map<String, dynamic> toJson() => {
        't': startedAt.toIso8601String(),
        'd': totalDuration.inMilliseconds,
        '0to100': zeroTo100?.inMilliseconds,
        'sp': maxSpeedKmh,
        'rpm': maxRpm,
        'g': maxG,
        'laps': laps.map((l) => l.inMilliseconds).toList(),
        'gps': gpsUsed,
      };

  factory _TrackSession.fromJson(Map<String, dynamic> j) => _TrackSession(
        startedAt: DateTime.parse(j['t'] as String),
        totalDuration: Duration(milliseconds: (j['d'] as num).toInt()),
        zeroTo100: j['0to100'] == null
            ? null
            : Duration(milliseconds: (j['0to100'] as num).toInt()),
        maxSpeedKmh: (j['sp'] as num).toDouble(),
        maxRpm: (j['rpm'] as num).toDouble(),
        maxG: (j['g'] as num).toDouble(),
        laps: ((j['laps'] as List?) ?? const [])
            .cast<num>()
            .map((m) => Duration(milliseconds: m.toInt()))
            .toList(),
        gpsUsed: (j['gps'] as bool?) ?? false,
      );
}

class TrackModeScreen extends StatefulWidget {
  const TrackModeScreen({super.key});

  @override
  State<TrackModeScreen> createState() => _TrackModeScreenState();
}

class _TrackModeScreenState extends State<TrackModeScreen> {
  static const _kStorageKey = 'track_sessions_v1';

  bool _running = false;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Duration? _zeroTo100;
  Duration? _zeroTo60Mph; // 0..96.56 km/h
  double _maxSpeed = 0;
  double _maxRpm = 0;
  double _maxG = 0;
  Timer? _ticker;
  final List<Duration> _laps = [];
  double? _lastSpeed;
  DateTime? _lastSpeedTime;
  bool _zeroTo100Beeped = false;

  List<_TrackSession> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Pornim GPS-ul deja, ca utilizatorul sa vada in header daca are fix
    // inainte sa apese START.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gps = LocationService.I;
      if (await gps.ensurePermission()) {
        await gps.start();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _history = list.map(_TrackSession.fromJson).toList();
      if (mounted) setState(() {});
    } catch (_) {/* corrupt cache, ignore */}
  }

  Future<void> _saveCurrentSession() async {
    if (_startedAt == null) return;
    final session = _TrackSession(
      startedAt: _startedAt!,
      totalDuration: _elapsed,
      zeroTo100: _zeroTo100,
      maxSpeedKmh: _maxSpeed,
      maxRpm: _maxRpm,
      maxG: _maxG,
      laps: List.of(_laps),
      gpsUsed: LocationService.I.hasFix,
    );
    _history.insert(0, session);
    while (_history.length > 20) {
      _history.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kStorageKey,
      jsonEncode(_history.map((s) => s.toJson()).toList()),
    );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Sesiune salvata · ${_history.length} in istoric'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Duration? get _bestZeroTo100 {
    final times = _history
        .where((s) => s.zeroTo100 != null)
        .map((s) => s.zeroTo100!)
        .toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.first;
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      HapticFeedback.heavyImpact();
      setState(() => _running = false);
      // La STOP, ofera optiunea de salvare daca avem date utile.
      if (_maxSpeed > 5 || _laps.isNotEmpty) {
        _saveCurrentSession();
      }
    } else {
      HapticFeedback.mediumImpact();
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _zeroTo100 = null;
      _zeroTo60Mph = null;
      _maxSpeed = 0;
      _maxRpm = 0;
      _maxG = 0;
      _laps.clear();
      _lastSpeed = null;
      _lastSpeedTime = null;
      _zeroTo100Beeped = false;
      _running = true;

      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || !_running) return;
        final live = context.read<LiveDataProvider>();
        final speed = live.latest[0x0D]?.value ?? 0.0;
        final rpm = live.latest[0x0C]?.value ?? 0.0;

        if (_zeroTo60Mph == null && speed >= 96.56 && _startedAt != null) {
          _zeroTo60Mph = DateTime.now().difference(_startedAt!);
          HapticFeedback.lightImpact();
        }
        if (_zeroTo100 == null && speed >= 100 && _startedAt != null) {
          _zeroTo100 = DateTime.now().difference(_startedAt!);
          if (!_zeroTo100Beeped) {
            _zeroTo100Beeped = true;
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.alert);
          }
        }
        if (speed > _maxSpeed) _maxSpeed = speed;
        if (rpm > _maxRpm) _maxRpm = rpm;

        final now = DateTime.now();
        if (_lastSpeed != null && _lastSpeedTime != null) {
          final dtMs = now.difference(_lastSpeedTime!).inMilliseconds;
          if (dtMs > 0) {
            final dvMs = ((speed - _lastSpeed!) / 3.6);
            final acc = dvMs / (dtMs / 1000.0);
            final g = (acc / 9.81).abs();
            if (g > _maxG) _maxG = g;
          }
        }
        _lastSpeed = speed;
        _lastSpeedTime = now;

        setState(() {
          _elapsed = DateTime.now().difference(_startedAt!);
        });
      });
      setState(() {});
    }
  }

  void _addLap() {
    if (!_running) return;
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    setState(() => _laps.insert(0, _elapsed));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$m:$s.$ms';
  }

  String _fmt0to100(Duration? d) {
    if (d == null) return '— . — —';
    final secs = d.inMilliseconds / 1000;
    return secs.toStringAsFixed(2);
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.orange, size: 18),
                  const Gap(8),
                  Text('SESIUNI SALVATE · ${_history.length}',
                      style: AppText.label(
                          size: 11,
                          color: AppColors.orange,
                          weight: FontWeight.w900)),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.remove(_kStorageKey);
                        setState(() => _history.clear());
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.danger),
                      label: Text('CLEAR',
                          style: AppText.label(
                              size: 10,
                              color: AppColors.danger,
                              weight: FontWeight.w800)),
                    ),
                ],
              ),
              const Gap(8),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('Nicio sesiune salvata inca.',
                      textAlign: TextAlign.center,
                      style: AppText.body(
                          size: 13, color: AppColors.textMuted)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (_, i) {
                      final s = _history[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHi,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.orange
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.flag_rounded,
                                  color: AppColors.orange, size: 16),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_fmtDate(s.startedAt),
                                      style: AppText.label(
                                          size: 10,
                                          color: AppColors.textMuted)),
                                  const Gap(2),
                                  Text(
                                    '0-100 ${_fmt0to100(s.zeroTo100)}s · '
                                    'max ${s.maxSpeedKmh.toStringAsFixed(0)} km/h · '
                                    '${s.laps.length} lap-uri',
                                    style: AppText.body(size: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (s.gpsUsed)
                              const Icon(Icons.gps_fixed_rounded,
                                  color: AppColors.ok, size: 14),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    String hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff.inHours < 24) return 'AZI · $hm';
    if (diff.inDays < 7) return '${diff.inDays} ZILE · $hm';
    return '${d.day}.${d.month}.${d.year} · $hm';
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveDataProvider>();
    final gps = context.watch<LocationService>();
    final speed = live.latest[0x0D]?.value ?? 0.0;
    final best = _bestZeroTo100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRACK MODE'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _history.isNotEmpty,
              label: Text('${_history.length}'),
              child: const Icon(Icons.emoji_events_rounded),
            ),
            tooltip: 'Istoric sesiuni',
            onPressed: _showHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_rounded,
                      color: AppColors.orange, size: 22),
                  const Gap(8),
                  Text('TRACK MODE',
                      style: AppText.label(
                          size: 13,
                          color: AppColors.orange,
                          weight: FontWeight.w900)),
                  const Gap(8),
                  _gpsBadge(gps),
                  const Spacer(),
                  Text(
                    _running ? 'RECORDING' : 'STANDBY',
                    style: AppText.label(
                      size: 10,
                      color:
                          _running ? AppColors.red : AppColors.textMuted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // 0-100 timer cu best ever
              NeonCard(
                showGlow: true,
                glow: AppColors.orange,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0 — 100 KM/H',
                            style: AppText.label(
                                size: 11,
                                color: AppColors.orange,
                                weight: FontWeight.w800)),
                        if (best != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.ok.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.ok
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'BEST ${_fmt0to100(best)}s',
                              style: AppText.label(
                                  size: 9,
                                  color: AppColors.ok,
                                  weight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const Gap(10),
                    Text(
                      _fmt0to100(_zeroTo100),
                      style: AppText.digital(
                          size: 64,
                          color: _zeroTo100 != null
                              ? AppColors.orange
                              : AppColors.text),
                    ),
                    Text('SECONDS',
                        style: AppText.label(
                            size: 10, color: AppColors.textMuted)),
                    if (_zeroTo60Mph != null) ...[
                      const Gap(6),
                      Text(
                        '0-60 mph: ${_fmt0to100(_zeroTo60Mph)}s',
                        style: AppText.label(
                            size: 10, color: AppColors.cyan),
                      ),
                    ],
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0),

              const Gap(14),

              // Stats row: G + speed + RPM
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'G-FORCE',
                      value: _maxG.toStringAsFixed(2),
                      color: AppColors.cyan,
                      icon: Icons.center_focus_strong_rounded,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatBlock(
                      label: 'MAX SPEED',
                      value: _maxSpeed.toStringAsFixed(0),
                      unit: 'km/h',
                      color: AppColors.red,
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatBlock(
                      label: 'MAX RPM',
                      value: _maxRpm.toStringAsFixed(0),
                      color: AppColors.orange,
                      icon: Icons.electric_bolt_rounded,
                    ),
                  ),
                ],
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0),

              const Gap(14),

              // Live speed bar
              NeonCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('CURRENT', style: AppText.label(size: 10)),
                        const Spacer(),
                        Text(
                          '${speed.toStringAsFixed(0)} km/h',
                          style: AppText.digital(
                              size: 18, color: AppColors.cyan),
                        ),
                      ],
                    ),
                    const Gap(8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (speed / 260).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceHi,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.cyan),
                      ),
                    ),
                    const Gap(6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: AppText.label(size: 9)),
                        Text('260', style: AppText.label(size: 9)),
                      ],
                    ),
                    const Gap(14),
                    Row(
                      children: [
                        Text(
                          _fmt(_elapsed),
                          style: AppText.digital(
                              size: 26, color: AppColors.text),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _running ? _addLap : null,
                          icon: const Icon(Icons.timer_rounded, size: 16),
                          label: Text('LAP',
                              style: AppText.label(
                                  size: 10,
                                  color: AppColors.cyan,
                                  weight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
                  .animate(delay: 150.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0),

              const Gap(14),

              if (_laps.isNotEmpty) ...[
                Expanded(
                  child: NeonCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LAPS', style: AppText.label(size: 10)),
                        const Gap(8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _laps.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 14, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final lap = _laps[i];
                              return Row(
                                children: [
                                  Text('#${_laps.length - i}',
                                      style: AppText.label(
                                          size: 11,
                                          color: AppColors.textMuted)),
                                  const Spacer(),
                                  Text(_fmt(lap),
                                      style: AppText.digital(
                                          size: 16,
                                          color: AppColors.cyan)),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(12),
              ] else
                const Spacer(),

              RacingButton(
                label: _running ? 'STOP & SAVE' : 'START SESSION',
                icon: _running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: _running ? AppColors.red : AppColors.orange,
                isOn: _running,
                onPressed: _toggle,
              )
                  .animate(delay: 250.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpsBadge(LocationService gps) {
    final (label, color, icon) = !gps.isGranted
        ? ('GPS OFF', AppColors.warn, Icons.location_disabled_rounded)
        : !gps.hasFix
            ? ('SAT...', AppColors.cyan, Icons.gps_not_fixed_rounded)
            : ('GPS', AppColors.ok, Icons.gps_fixed_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const Gap(4),
          Text(label,
              style:
                  AppText.label(size: 9, color: color, weight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final IconData icon;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              Icon(icon, size: 14, color: color),
              const Gap(4),
              Text(label, style: AppText.label(size: 9.5)),
            ],
          ),
          const Gap(6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: AppText.digital(size: 20, color: color)),
                if (unit != null)
                  TextSpan(
                      text: ' $unit',
                      style:
                          AppText.body(size: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
