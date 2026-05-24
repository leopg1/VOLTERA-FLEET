import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/location_service.dart';
import '../design/design.dart';
import '../providers/live_data_provider.dart';

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
  Duration? _zeroTo60Mph;
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
    } catch (_) {
      /* corrupt cache, ignore */
    }
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
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: context.tokens.ok,
      content: Text('Session saved · ${_history.length} in history'),
      duration: const Duration(seconds: 2),
    ));
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
    final ms =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$ms';
  }

  String _fmt0to100(Duration? d) {
    if (d == null) return '—';
    final secs = d.inMilliseconds / 1000;
    return secs.toStringAsFixed(2);
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                VSpace.s16, VSpace.s8, VSpace.s16, VSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Saved sessions  ·  ${_history.length}',
                        style: VType.title18),
                    const Spacer(),
                    if (_history.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.remove(_kStorageKey);
                          if (!mounted) return;
                          setState(() => _history.clear());
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 16, color: t.danger),
                        label: Text('Clear',
                            style: VType.body13.copyWith(color: t.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: VSpace.s12),
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: VSpace.s32),
                    child: EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'No saved sessions',
                      body: 'Run a session and stop to save automatically.',
                    ),
                  )
                else
                  Flexible(
                    child: ClipRRect(
                      borderRadius: VRadius.brMd,
                      child: Container(
                        color: t.surface,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _history.length,
                          itemBuilder: (_, i) {
                            final s = _history[i];
                            return VListTile(
                              divider: i < _history.length - 1,
                              leadingIcon: Icons.flag_rounded,
                              title: _fmtDate(s.startedAt),
                              subtitle:
                                  '0–100 ${_fmt0to100(s.zeroTo100)}s  ·  max ${s.maxSpeedKmh.toStringAsFixed(0)} km/h  ·  ${s.laps.length} laps',
                              trailing: s.gpsUsed
                                  ? Icon(Icons.gps_fixed_rounded,
                                      color: t.ok, size: 14)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff.inHours < 24) return 'Today  ·  $hm';
    if (diff.inDays < 7) return '${diff.inDays}d ago  ·  $hm';
    return '${d.day}.${d.month}.${d.year}  ·  $hm';
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveDataProvider>();
    final gps = context.watch<LocationService>();
    final t = context.tokens;
    final speed = live.latest[0x0D]?.value ?? 0.0;
    final best = _bestZeroTo100;

    return VScaffold(
      appBar: VAppBar(
        title: 'Track Mode',
        subtitle: _running ? 'Recording' : 'Standby',
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _history.isNotEmpty,
              label: Text('${_history.length}'),
              child: const Icon(Icons.emoji_events_rounded),
            ),
            tooltip: 'Session history',
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s16),
              children: [
                // ─── GPS + state row
                Row(
                  children: [
                    _GpsBadge(gps: gps),
                    const SizedBox(width: VSpace.s8),
                    StatusBadge(
                      label: _running ? 'Recording' : 'Standby',
                      status: _running ? VStatus.danger : VStatus.neutral,
                      icon: _running
                          ? Icons.fiber_manual_record_rounded
                          : Icons.pause_rounded,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.s12),

                // ─── 0-100 hero
                VCard.hero(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0 → 100 km/h',
                              style: VType.label11
                                  .copyWith(color: t.textMuted)),
                          if (best != null)
                            StatusBadge(
                              label: 'Best ${_fmt0to100(best)}s',
                              status: VStatus.ok,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: VSpace.s12),
                      Text(
                        _fmt0to100(_zeroTo100),
                        style: VType.display72.copyWith(
                          color: _zeroTo100 != null
                              ? t.textStrong
                              : t.textDisabled,
                        ),
                      ),
                      Text('seconds',
                          style: VType.body15.copyWith(color: t.textMuted)),
                      if (_zeroTo60Mph != null) ...[
                        const SizedBox(height: VSpace.s8),
                        Text(
                          '0–60 mph: ${_fmt0to100(_zeroTo60Mph)}s',
                          style: VType.body13.copyWith(color: t.accent),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: VSpace.s12),

                // ─── Stats row
                Row(
                  children: [
                    Expanded(
                      child: VCard(
                        child: MetricBlock(
                          label: 'G-force',
                          value: _maxG.toStringAsFixed(2),
                          unit: 'g',
                          size: MetricSize.md,
                          leadingIcon: Icons.center_focus_strong_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.cardGap),
                    Expanded(
                      child: VCard(
                        child: MetricBlock(
                          label: 'Top speed',
                          value: _maxSpeed.toStringAsFixed(0),
                          unit: 'km/h',
                          size: MetricSize.md,
                          leadingIcon: Icons.speed_rounded,
                          status: _maxSpeed > 200
                              ? VStatus.warn
                              : VStatus.neutral,
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.cardGap),
                    Expanded(
                      child: VCard(
                        child: MetricBlock(
                          label: 'Top RPM',
                          value: _maxRpm.toStringAsFixed(0),
                          size: MetricSize.md,
                          leadingIcon: Icons.electric_bolt_rounded,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: VSpace.s12),

                // ─── Live speed + timer + lap
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Current',
                              style: VType.label11
                                  .copyWith(color: t.textMuted)),
                          const Spacer(),
                          Text('${speed.toStringAsFixed(0)} km/h',
                              style: VType.mono15
                                  .copyWith(color: t.textStrong)),
                        ],
                      ),
                      const SizedBox(height: VSpace.s8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (speed / 260).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: t.canvas,
                          valueColor:
                              AlwaysStoppedAnimation(t.accent),
                        ),
                      ),
                      const SizedBox(height: VSpace.s4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0',
                              style: VType.body13
                                  .copyWith(color: t.textMuted)),
                          Text('260',
                              style: VType.body13
                                  .copyWith(color: t.textMuted)),
                        ],
                      ),
                      const SizedBox(height: VSpace.s16),
                      Row(
                        children: [
                          Expanded(
                            child: MetricBlock(
                              label: 'Elapsed',
                              value: _fmt(_elapsed),
                              size: MetricSize.md,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _running ? _addLap : null,
                            icon: const Icon(Icons.timer_rounded, size: 16),
                            label: const Text('Lap'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_laps.isNotEmpty) ...[
                  const SizedBox(height: VSpace.s12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        VSpace.s4, 0, VSpace.s4, VSpace.s8),
                    child: Text('LAPS',
                        style: VType.label11
                            .copyWith(color: t.textMuted)),
                  ),
                  ClipRRect(
                    borderRadius: VRadius.brMd,
                    child: Container(
                      color: t.surface,
                      child: Column(
                        children: [
                          for (int i = 0; i < _laps.length; i++)
                            ValueRow(
                              label: '#${_laps.length - i}',
                              value: _fmt(_laps[i]),
                              divider: i < _laps.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    label: const Text('Stop & save'),
                    onPressed: _toggle,
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start session'),
                    onPressed: _toggle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _GpsBadge extends StatelessWidget {
  final LocationService gps;
  const _GpsBadge({required this.gps});

  @override
  Widget build(BuildContext context) {
    final (label, status, icon) = !gps.isGranted
        ? ('GPS off', VStatus.warn, Icons.location_disabled_rounded)
        : !gps.hasFix
            ? ('Acquiring', VStatus.info, Icons.gps_not_fixed_rounded)
            : ('GPS live', VStatus.ok, Icons.gps_fixed_rounded);
    return StatusBadge(
      label: label,
      status: status,
      icon: icon,
      dense: true,
    );
  }
}
