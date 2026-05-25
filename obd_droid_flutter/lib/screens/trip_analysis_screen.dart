import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../core/services/location_service.dart';
import '../design/design.dart';
import '../providers/live_data_provider.dart';
import '../providers/trip_provider.dart';

/// Trip Analysis — focus: traseul GPS pe harta + scor eco dupa.
/// Map mare, stats curate, single accent. Niciun glow.
class TripAnalysisScreen extends StatefulWidget {
  const TripAnalysisScreen({super.key});

  @override
  State<TripAnalysisScreen> createState() => _TripAnalysisScreenState();
}

class _TripAnalysisScreenState extends State<TripAnalysisScreen> {
  Trip? _viewing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gps = LocationService.I;
      final granted = await gps.ensurePermission();
      if (granted) await gps.start();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TripProvider>();
    final live = context.watch<LiveDataProvider>();
    final gps = context.watch<LocationService>();
    final trip = _viewing ??
        tp.activeTrip ??
        (tp.saved.isNotEmpty ? tp.saved.first : null);
    final isLive = trip != null && tp.activeTrip == trip;
    final t = context.tokens;

    return VScaffold(
      body: Column(
        children: [
          if (tp.saved.isNotEmpty || tp.isRecording)
            Padding(
              padding: const EdgeInsets.only(top: VSpace.s8),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.list_rounded),
                  tooltip: 'Saved trips',
                  onPressed: () => _showHistorySheet(context, tp),
                ),
              ),
            ),
          Expanded(
            child: trip == null
                ? _EmptyHero(gps: gps)
                : _TripDetail(trip: trip, isLive: isLive, gps: gps),
          ),
          Padding(
            padding: const EdgeInsets.only(
                top: VSpace.s8, bottom: VSpace.s16),
            child: tp.isRecording
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop trip'),
                    onPressed: () async {
                      await tp.stopTrip();
                      if (mounted) setState(() => _viewing = null);
                    },
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start trip'),
                    onPressed: () {
                      tp.startTrip(live);
                      setState(() => _viewing = null);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistorySheet(
    BuildContext context,
    TripProvider tp,
  ) async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        final entries = [
          if (tp.activeTrip != null) tp.activeTrip!,
          ...tp.saved,
        ];
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
                    const Text('Saved trips', style: VType.title18),
                    const Spacer(),
                    if (tp.saved.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          await tp.clearAll();
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 16, color: t.danger),
                        label: Text('Clear all',
                            style: VType.body13
                                .copyWith(color: t.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: VSpace.s12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final tr = entries[i];
                      final isActive = tr == tp.activeTrip;
                      return _TripSheetItem(
                        trip: tr,
                        isActive: isActive,
                        onTap: () {
                          setState(() => _viewing = tr);
                          Navigator.pop(sheetCtx);
                        },
                        onDelete: isActive
                            ? null
                            : () async {
                                await tp.deleteTrip(tr.id);
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripSheetItem extends StatelessWidget {
  final Trip trip;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _TripSheetItem({
    required this.trip,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VListTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: isActive
              ? const StatusDot(status: VStatus.danger, pulse: true, size: 10)
              : Icon(Icons.route_rounded, color: t.textMuted, size: 20),
        ),
      ),
      title: isActive
          ? 'Recording · ${_fmtDuration(trip.duration)}'
          : _fmtDate(trip.startedAt),
      subtitle:
          '${trip.distanceKm.toStringAsFixed(1)} km  ·  max ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h  ·  eco ${trip.ecoScore}',
      onTap: onTap,
      trailing: onDelete != null
          ? IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  color: t.textDisabled, size: 18),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty hero
// ─────────────────────────────────────────────────────────────────────

class _EmptyHero extends StatelessWidget {
  final LocationService gps;
  const _EmptyHero({required this.gps});

  @override
  Widget build(BuildContext context) {
    final waiting = gps.isGranted && !gps.hasFix;
    final (label, status, icon) = !gps.isGranted
        ? ('GPS off', VStatus.warn, Icons.location_disabled_rounded)
        : waiting
            ? ('Searching satellites', VStatus.info, Icons.gps_not_fixed_rounded)
            : ('GPS live', VStatus.ok, Icons.gps_fixed_rounded);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s16),
      children: [
        VCard.hero(
          padding: const EdgeInsets.all(VSpace.s16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: status.resolve(context.tokens)),
                  const SizedBox(width: VSpace.s8),
                  Text(label,
                      style: VType.body13.copyWith(
                          color: status.resolve(context.tokens))),
                  const Spacer(),
                  if (gps.hasFix && gps.accuracyM != null)
                    Text('±${gps.accuracyM!.toStringAsFixed(0)} m',
                        style: VType.body13.copyWith(
                            color: context.tokens.textMuted)),
                ],
              ),
              const SizedBox(height: VSpace.s12),
              AspectRatio(
                aspectRatio: 1.9,
                child: ClipRRect(
                  borderRadius: VRadius.brMd,
                  child: _RealMap(
                    samples: const [],
                    highlightLast: true,
                    liveLat: gps.hasFix ? gps.lat : null,
                    liveLon: gps.hasFix ? gps.lon : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.s24),
        const EmptyState(
          icon: Icons.route_rounded,
          title: 'No trip recorded yet',
          body: 'Tap Start trip to record a route. The map follows your GPS '
              'position in real time.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Trip detail
// ─────────────────────────────────────────────────────────────────────

class _TripDetail extends StatelessWidget {
  final Trip trip;
  final bool isLive;
  final LocationService gps;
  const _TripDetail({
    required this.trip,
    required this.isLive,
    required this.gps,
  });

  VStatus _ecoStatus(int s) {
    if (s >= 80) return VStatus.ok;
    if (s >= 60) return VStatus.info;
    if (s >= 40) return VStatus.warn;
    return VStatus.danger;
  }

  String _ecoLabel(int s) {
    if (s >= 90) return 'Eco master';
    if (s >= 80) return 'Excellent';
    if (s >= 60) return 'Good';
    if (s >= 40) return 'Average';
    return 'Aggressive';
  }

  String _ecoTip(Trip t) {
    if (t.harshBrakeEvents.length > 3) {
      return 'Anticipate traffic to reduce hard braking.';
    }
    if (t.harshAccelEvents.length > 3) {
      return 'Press the throttle progressively — saves 10–15% fuel.';
    }
    if (t.consumptionL100 > 9) {
      return 'Keep RPM under 2500 in urban driving.';
    }
    if (t.maxSpeedKmh > 140) {
      return 'Above 130 km/h consumption rises exponentially.';
    }
    return 'Your driving style is efficient. Keep it up.';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasGps = trip.hasGpsTrack;
    final mapStatus =
        hasGps ? (isLive ? VStatus.danger : VStatus.ok) : VStatus.info;
    final mapLabel = hasGps
        ? (isLive ? 'GPS live  ·  ${_fmtDuration(trip.duration)}' : 'GPS trace')
        : (isLive
            ? 'Synthetic  ·  ${_fmtDuration(trip.duration)}'
            : 'Synthetic trace');

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s16),
      children: [
        // ─── Map card
        VCard.hero(
          padding: const EdgeInsets.all(VSpace.s16),
          child: Column(
            children: [
              Row(
                children: [
                  StatusDot(status: mapStatus, pulse: isLive),
                  const SizedBox(width: VSpace.s8),
                  Text(mapLabel,
                      style: VType.body13.copyWith(color: t.textDefault)),
                  const Spacer(),
                  if (isLive && gps.accuracyM != null)
                    Text('±${gps.accuracyM!.toStringAsFixed(0)} m',
                        style: VType.body13.copyWith(color: t.textMuted)),
                  const SizedBox(width: VSpace.s8),
                  Text('${trip.samples.length} pts',
                      style: VType.body13.copyWith(color: t.textMuted)),
                ],
              ),
              const SizedBox(height: VSpace.s12),
              AspectRatio(
                aspectRatio: 1.9,
                child: ClipRRect(
                  borderRadius: VRadius.brMd,
                  child: hasGps
                      ? _RealMap(
                          samples: trip.samples,
                          highlightLast: isLive,
                          liveLat: isLive && gps.hasFix ? gps.lat : null,
                          liveLon: isLive && gps.hasFix ? gps.lon : null,
                        )
                      : Container(
                          color: t.canvas,
                          child: CustomPaint(
                            painter: _SyntheticTracePainter(
                              samples: trip.samples,
                              highlightLast: isLive,
                              accent: t.accent,
                              hairline: t.hairline,
                              ok: t.ok,
                              danger: t.danger,
                              warn: t.warn,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: VSpace.s12),

        // ─── Eco score card
        VCard(
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: LiveArcMeter(
                  value: trip.ecoScore.toDouble(),
                  max: 100,
                  label: 'Eco',
                  status: _ecoStatus(trip.ecoScore),
                  thickness: 3,
                ),
              ),
              const SizedBox(width: VSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_ecoLabel(trip.ecoScore),
                        style: VType.title18.copyWith(
                            color: _ecoStatus(trip.ecoScore).resolve(t))),
                    const SizedBox(height: VSpace.s4),
                    Text(_ecoTip(trip),
                        style:
                            VType.body13.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: VSpace.s12),

        // ─── Stats grid (2x3)
        _StatsGrid(trip: trip),

        const SizedBox(height: VSpace.s16),

        // ─── Speed chart
        VCard(
          padding: const EdgeInsets.fromLTRB(
              VSpace.s20, VSpace.s16, VSpace.s12, VSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Speed profile',
                      style: VType.title18.copyWith(color: t.textStrong)),
                  const Spacer(),
                  Text(
                    'avg ${trip.avgSpeedKmh.toStringAsFixed(0)}  ·  max ${trip.maxSpeedKmh.toStringAsFixed(0)}',
                    style: VType.body13.copyWith(color: t.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: VSpace.s12),
              SizedBox(
                height: 130,
                child: _SpeedChart(samples: trip.samples, accent: t.accent),
              ),
            ],
          ),
        ),

        const SizedBox(height: VSpace.s12),

        // ─── Driving events
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Driving events',
                  style: VType.title18.copyWith(color: t.textStrong)),
              const SizedBox(height: VSpace.s16),
              Row(
                children: [
                  Expanded(
                    child: _EventTile(
                      icon: Icons.fast_forward_rounded,
                      label: 'Hard accel',
                      value: trip.harshAccelEvents.length.toString(),
                      status: trip.harshAccelEvents.isEmpty
                          ? VStatus.neutral
                          : VStatus.warn,
                    ),
                  ),
                  Container(width: 1, height: 56, color: t.hairline),
                  Expanded(
                    child: _EventTile(
                      icon: Icons.fast_rewind_rounded,
                      label: 'Hard brake',
                      value: trip.harshBrakeEvents.length.toString(),
                      status: trip.harshBrakeEvents.isEmpty
                          ? VStatus.neutral
                          : VStatus.danger,
                    ),
                  ),
                  Container(width: 1, height: 56, color: t.hairline),
                  Expanded(
                    child: _EventTile(
                      icon: Icons.electric_bolt_rounded,
                      label: 'Max RPM',
                      value: trip.maxRpm.round().toString(),
                      status: VStatus.info,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Trip trip;
  const _StatsGrid({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Distance',
                  value: trip.distanceKm.toStringAsFixed(2),
                  unit: 'km',
                  size: MetricSize.md,
                  leadingIcon: Icons.straighten_rounded,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Duration',
                  value: _fmtDuration(trip.duration),
                  size: MetricSize.md,
                  leadingIcon: Icons.timer_outlined,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Avg speed',
                  value: trip.avgSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                  size: MetricSize.md,
                  leadingIcon: Icons.speed_rounded,
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
                  label: 'Top speed',
                  value: trip.maxSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                  size: MetricSize.md,
                  leadingIcon: Icons.flash_on_rounded,
                  status: trip.maxSpeedKmh > 140
                      ? VStatus.warn
                      : VStatus.neutral,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'Consumption',
                  value: trip.consumptionL100.toStringAsFixed(1),
                  unit: 'L/100',
                  size: MetricSize.md,
                  leadingIcon: Icons.local_gas_station_rounded,
                ),
              ),
            ),
            const SizedBox(width: VSpace.cardGap),
            Expanded(
              child: VCard(
                child: MetricBlock(
                  label: 'CO₂',
                  value: trip.co2Kg.toStringAsFixed(2),
                  unit: 'kg',
                  size: MetricSize.md,
                  leadingIcon: Icons.cloud_outlined,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VStatus status;
  const _EventTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = status.resolve(t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.s8),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: VSpace.s8),
          Text(value,
              style: VType.title24.copyWith(
                color: color,
                fontFamily: VType.mono,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: VType.body13.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Real OSM map (cleaned visuals)
// ─────────────────────────────────────────────────────────────────────

class _RealMap extends StatefulWidget {
  final List<TripSample> samples;
  final bool highlightLast;
  final double? liveLat;
  final double? liveLon;

  const _RealMap({
    required this.samples,
    required this.highlightLast,
    this.liveLat,
    this.liveLon,
  });

  @override
  State<_RealMap> createState() => _RealMapState();
}

class _RealMapState extends State<_RealMap> {
  final MapController _ctrl = MapController();
  bool _firstFit = false;

  @override
  void didUpdateWidget(_RealMap old) {
    super.didUpdateWidget(old);
    if (widget.highlightLast &&
        widget.liveLat != null &&
        widget.liveLon != null &&
        (widget.liveLat != old.liveLat || widget.liveLon != old.liveLon)) {
      _ctrl.move(LatLng(widget.liveLat!, widget.liveLon!), _ctrl.camera.zoom);
    }
  }

  LatLng _initialCenter() {
    if (widget.liveLat != null && widget.liveLon != null) {
      return LatLng(widget.liveLat!, widget.liveLon!);
    }
    final withGps = widget.samples.where((s) => s.hasGps).toList();
    if (withGps.isNotEmpty) {
      final last = withGps.last;
      return LatLng(last.lat!, last.lon!);
    }
    return const LatLng(47.6519, 26.2553); // Suceava fallback
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gpsSamples = widget.samples.where((s) => s.hasGps).toList();
    final polylinePoints =
        gpsSamples.map((s) => LatLng(s.lat!, s.lon!)).toList();

    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: _initialCenter(),
        initialZoom: 15,
        minZoom: 4,
        maxZoom: 19,
        backgroundColor: t.canvas,
        onMapReady: () {
          if (_firstFit || polylinePoints.length < 2) return;
          _firstFit = true;
          final bounds = LatLngBounds.fromPoints(polylinePoints);
          _ctrl.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(32),
            ),
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.voltera.flutter',
          maxZoom: 19,
          retinaMode: true,
          tileProvider: NetworkTileProvider(),
        ),
        if (polylinePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 4,
                color: t.accent,
                borderStrokeWidth: 1.5,
                borderColor: t.canvas,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (gpsSamples.isNotEmpty)
              Marker(
                point: LatLng(
                  gpsSamples.first.lat!,
                  gpsSamples.first.lon!,
                ),
                width: 16,
                height: 16,
                child: _MapDot(color: t.ok),
              ),
            for (final s in gpsSamples)
              if (s.accel > 3.5 || s.accel < -4.0)
                Marker(
                  point: LatLng(s.lat!, s.lon!),
                  width: 8,
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.accel > 3.5 ? t.warn : t.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.canvas, width: 1),
                    ),
                  ),
                ),
            if (widget.highlightLast &&
                widget.liveLat != null &&
                widget.liveLon != null)
              Marker(
                point: LatLng(widget.liveLat!, widget.liveLon!),
                width: 28,
                height: 28,
                child: _LivePin(color: t.danger),
              )
            else if (gpsSamples.isNotEmpty)
              Marker(
                point: LatLng(
                  gpsSamples.last.lat!,
                  gpsSamples.last.lon!,
                ),
                width: 16,
                height: 16,
                child: _MapDot(color: t.accent),
              ),
          ],
        ),
        // Attribution
        Padding(
          padding: const EdgeInsets.all(4),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OSM · © CARTO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontFamily: VType.sans,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapDot extends StatelessWidget {
  final Color color;
  const _MapDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: t.canvas, width: 2),
      ),
    );
  }
}

class _LivePin extends StatefulWidget {
  final Color color;
  const _LivePin({required this.color});

  @override
  State<_LivePin> createState() => _LivePinState();
}

class _LivePinState extends State<_LivePin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.6 + v * 1.4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color
                      .withValues(alpha: (0.25 * (1 - v)).clamp(0, 0.25)),
                ),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: t.canvas, width: 2),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Synthetic trace painter — pentru trip-uri fara GPS (mock / demo)
// ─────────────────────────────────────────────────────────────────────

class _SyntheticTracePainter extends CustomPainter {
  final List<TripSample> samples;
  final bool highlightLast;
  final Color accent;
  final Color hairline;
  final Color ok;
  final Color danger;
  final Color warn;

  _SyntheticTracePainter({
    required this.samples,
    required this.highlightLast,
    required this.accent,
    required this.hairline,
    required this.ok,
    required this.danger,
    required this.warn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    if (samples.length < 2) return;

    final pts = [for (final s in samples) Offset(s.x, s.y)];
    double minX = pts.first.dx;
    double maxX = pts.first.dx;
    double minY = pts.first.dy;
    double maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final spanX = max(maxX - minX, 60.0);
    final spanY = max(maxY - minY, 60.0);
    const pad = 24.0;
    final scale = min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final ox = (size.width - spanX * scale) / 2 - minX * scale;
    final oy = (size.height - spanY * scale) / 2 - minY * scale;

    Offset toCanvas(int i) {
      final p = pts[i];
      return Offset(p.dx * scale + ox, size.height - (p.dy * scale + oy));
    }

    final path = Path();
    final first = toCanvas(0);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < samples.length; i++) {
      final p = toCanvas(i);
      path.lineTo(p.dx, p.dy);
    }
    final stroke = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    // Start marker
    canvas.drawCircle(first, 5, Paint()..color = ok);

    // End marker
    final last = toCanvas(samples.length - 1);
    canvas.drawCircle(
      last,
      5,
      Paint()..color = highlightLast ? danger : accent,
    );

    // Harsh-event annotations
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.accel > 3.5) {
        canvas.drawCircle(toCanvas(i), 2.5, Paint()..color = warn);
      } else if (s.accel < -4.0) {
        canvas.drawCircle(toCanvas(i), 2.5, Paint()..color = danger);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = hairline
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SyntheticTracePainter old) =>
      old.samples.length != samples.length ||
      old.highlightLast != highlightLast;
}

// ─────────────────────────────────────────────────────────────────────
// Speed chart
// ─────────────────────────────────────────────────────────────────────

class _SpeedChart extends StatelessWidget {
  final List<TripSample> samples;
  final Color accent;
  const _SpeedChart({required this.samples, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (samples.length < 2) {
      return Center(
        child: Text(
          'Needs >2 points',
          style: VType.body13.copyWith(color: t.textDisabled),
        ),
      );
    }
    final t0 = samples.first.tMs;
    final spots = <FlSpot>[
      for (final s in samples) FlSpot((s.tMs - t0) / 1000.0, s.speed),
    ];
    final maxX = spots.last.x;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: max(60.0, samples.map((s) => s.speed).reduce(max) * 1.1),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: t.hairline, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 40,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: VType.body13.copyWith(color: t.textDisabled),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: maxX / 4,
              getTitlesWidget: (v, _) {
                final s = v.toInt();
                final mm = (s ~/ 60).toString().padLeft(2, '0');
                final ss = (s % 60).toString().padLeft(2, '0');
                return Text(
                  '$mm:$ss',
                  style: VType.body13.copyWith(color: t.textDisabled),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            color: accent,
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  final hm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (diff.inHours < 24) return 'Today  ·  $hm';
  if (diff.inDays < 7) return '${diff.inDays} days ago  ·  $hm';
  return '${d.day}.${d.month}.${d.year}  ·  $hm';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
