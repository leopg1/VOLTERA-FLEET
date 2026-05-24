import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../core/services/location_service.dart';
import '../providers/live_data_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_card.dart';
import '../widgets/racing_button.dart';

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
    // Cerem permisiune GPS la deschiderea ecranului. Daca user-ul accepta,
    // pornim stream-ul de pozitii ca harta sa fie populata inca de la START.
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
    final trip = _viewing ?? tp.activeTrip ?? (tp.saved.isNotEmpty ? tp.saved.first : null);
    final isLive = trip != null && tp.activeTrip == trip;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRIP ANALYSIS'),
        actions: [
          if (tp.saved.isNotEmpty || tp.isRecording)
            IconButton(
              icon: const Icon(Icons.list_rounded),
              tooltip: 'Trasee salvate',
              onPressed: () => _showHistorySheet(context, tp),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: trip == null
                  ? _emptyHero(gps)
                  : _TripDetail(trip: trip, isLive: isLive, gps: gps),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (tp.isRecording) ...[
                    Expanded(
                      child: RacingButton(
                        label: 'STOP TRIP',
                        icon: Icons.stop_rounded,
                        color: AppColors.danger,
                        isOn: true,
                        height: 50,
                        onPressed: () async {
                          await tp.stopTrip();
                          if (mounted) setState(() => _viewing = null);
                        },
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: RacingButton(
                        label: 'START TRIP',
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.cyan,
                        isOn: false,
                        height: 50,
                        onPressed: () {
                          tp.startTrip(live);
                          setState(() => _viewing = null);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHero(LocationService gps) {
    final waiting = gps.isGranted && !gps.hasFix;
    final gpsBadge = !gps.isGranted
        ? ('GPS OFF', AppColors.warn, Icons.location_disabled_rounded)
        : waiting
            ? ('CAUT SATELITI...', AppColors.cyan, Icons.gps_not_fixed_rounded)
            : ('GPS LIVE', AppColors.ok, Icons.gps_fixed_rounded);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Harta reala OSM, centrata pe pozitia GPS curenta (sau Suceava
          // ca fallback). Vizibila inca de la deschiderea ecranului.
          NeonCard(
            showGlow: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(gpsBadge.$3, size: 14, color: gpsBadge.$2),
                    const Gap(6),
                    Text(gpsBadge.$1,
                        style: AppText.label(
                            size: 10,
                            color: gpsBadge.$2,
                            weight: FontWeight.w900)),
                    const Spacer(),
                    if (gps.hasFix && gps.accuracyM != null)
                      Text('±${gps.accuracyM!.toStringAsFixed(0)}m',
                          style: AppText.label(
                              size: 9, color: AppColors.textMuted)),
                  ],
                ),
                const Gap(8),
                AspectRatio(
                  aspectRatio: 1.9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
          const Gap(20),
          Center(
            child: Column(
              children: [
                Text('NICIUN TRASEU INREGISTRAT',
                    textAlign: TextAlign.center,
                    style: AppText.label(
                        size: 13,
                        color: AppColors.cyan,
                        weight: FontWeight.w900)),
                const Gap(8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Apasa START TRIP pentru a inregistra un drum. '
                    'Harta urmareste pozitia GPS-ului in timp real.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistorySheet(
      BuildContext context, TripProvider tp) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final entries = [
          if (tp.activeTrip != null) tp.activeTrip!,
          ...tp.saved,
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text('TRASEE INREGISTRATE',
                        style: AppText.label(
                            size: 11,
                            color: AppColors.cyan,
                            weight: FontWeight.w900)),
                    const Spacer(),
                    if (tp.saved.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          await tp.clearAll();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.danger),
                        label: Text('CLEAR ALL',
                            style: AppText.label(
                                size: 10,
                                color: AppColors.danger,
                                weight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Gap(8),
                  itemBuilder: (_, i) {
                    final t = entries[i];
                    final isActive = t == tp.activeTrip;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _viewing = t);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHi,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isActive
                                  ? AppColors.danger.withOpacity(0.5)
                                  : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isActive
                                    ? Icons.fiber_manual_record_rounded
                                    : Icons.route_rounded,
                                color: isActive
                                    ? AppColors.danger
                                    : AppColors.cyan,
                                size: 18,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isActive
                                        ? 'INREGISTREAZA · ${_fmtDuration(t.duration)}'
                                        : _fmtDate(t.startedAt),
                                    style: AppText.label(
                                        size: 10,
                                        color: isActive
                                            ? AppColors.danger
                                            : AppColors.textMuted,
                                        weight: FontWeight.w800),
                                  ),
                                  const Gap(2),
                                  Text(
                                    '${t.distanceKm.toStringAsFixed(1)} km · '
                                    'max ${t.maxSpeedKmh.toStringAsFixed(0)} km/h · '
                                    'eco ${t.ecoScore}',
                                    style: AppText.body(size: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (!isActive)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.textMuted, size: 18),
                                onPressed: () async {
                                  await tp.deleteTrip(t.id);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

class _TripDetail extends StatelessWidget {
  final Trip trip;
  final bool isLive;
  final LocationService gps;
  const _TripDetail({
    required this.trip,
    required this.isLive,
    required this.gps,
  });

  @override
  Widget build(BuildContext context) {
    final eco = trip.ecoScore;
    final hasGps = trip.hasGpsTrack;
    // Label-ul header-ului hartii: distingem real GPS vs traseu sintetizat.
    final mapLabel = hasGps
        ? (isLive ? 'GPS LIVE · ${_fmtDuration(trip.duration)}' : 'GPS TRACE')
        : (isLive
            ? 'TRACE SIMULAT · ${_fmtDuration(trip.duration)}'
            : 'TRACE SIMULAT');
    final mapColor = hasGps
        ? (isLive ? AppColors.danger : AppColors.ok)
        : (isLive ? AppColors.warn : AppColors.cyan);
    final mapIcon = hasGps
        ? Icons.gps_fixed_rounded
        : Icons.shuffle_rounded;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map card
          NeonCard(
            showGlow: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(mapIcon, color: mapColor, size: 16),
                    const Gap(8),
                    Text(
                      mapLabel,
                      style: AppText.label(
                          size: 10,
                          color: mapColor,
                          weight: FontWeight.w900),
                    ),
                    const Spacer(),
                    if (isLive && gps.accuracyM != null) ...[
                      Icon(Icons.signal_cellular_alt_rounded,
                          size: 11,
                          color: gps.accuracyM! < 15
                              ? AppColors.ok
                              : AppColors.warn),
                      const Gap(3),
                      Text('±${gps.accuracyM!.toStringAsFixed(0)}m',
                          style: AppText.label(
                              size: 9, color: AppColors.textMuted)),
                      const Gap(8),
                    ],
                    Text('${trip.samples.length} pts',
                        style: AppText.label(
                            size: 9, color: AppColors.textMuted)),
                  ],
                ),
                const Gap(8),
                AspectRatio(
                  aspectRatio: 1.9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasGps
                        ? _RealMap(
                            samples: trip.samples,
                            highlightLast: isLive,
                            liveLat:
                                isLive && gps.hasFix ? gps.lat : null,
                            liveLon:
                                isLive && gps.hasFix ? gps.lon : null,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLo,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: CustomPaint(
                              painter: _TripMapPainter(
                                samples: trip.samples,
                                highlightLast: isLive,
                                useGps: false,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),

          const Gap(12),

          // Eco score card
          NeonCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _EcoRing(score: eco),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ECO SCORE',
                          style: AppText.label(
                              size: 10,
                              color: _ecoColor(eco),
                              weight: FontWeight.w900)),
                      const Gap(4),
                      Text(_ecoLabel(eco),
                          style: AppText.title(
                              size: 18, color: _ecoColor(eco))),
                      const Gap(4),
                      Text(_ecoTip(trip),
                          style: AppText.body(
                              size: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 350.ms),

          const Gap(12),

          // Stats grid
          Row(
            children: [
              Expanded(
                  child: _statTile('DISTANTA',
                      trip.distanceKm.toStringAsFixed(2), 'km', AppColors.cyan,
                      Icons.straighten_rounded)),
              const Gap(8),
              Expanded(
                  child: _statTile('DURATA', _fmtDuration(trip.duration),
                      '', AppColors.cyan, Icons.timer_outlined)),
              const Gap(8),
              Expanded(
                  child: _statTile('VITEZA',
                      trip.avgSpeedKmh.toStringAsFixed(0), 'km/h',
                      AppColors.cyan, Icons.speed_rounded)),
            ],
          ).animate(delay: 200.ms).fadeIn(),

          const Gap(8),
          Row(
            children: [
              Expanded(
                  child: _statTile('MAX',
                      trip.maxSpeedKmh.toStringAsFixed(0), 'km/h',
                      AppColors.warn, Icons.flash_on_rounded)),
              const Gap(8),
              Expanded(
                  child: _statTile('CONSUM',
                      trip.consumptionL100.toStringAsFixed(1), 'L/100',
                      AppColors.cyan, Icons.local_gas_station_rounded)),
              const Gap(8),
              Expanded(
                  child: _statTile('CO₂',
                      trip.co2Kg.toStringAsFixed(2), 'kg',
                      AppColors.ok, Icons.cloud_outlined)),
            ],
          ).animate(delay: 250.ms).fadeIn(),

          const Gap(12),

          // Speed profile
          NeonCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('SPEED PROFILE', style: AppText.label(size: 10)),
                    const Spacer(),
                    Text(
                      'avg ${trip.avgSpeedKmh.toStringAsFixed(0)} · max ${trip.maxSpeedKmh.toStringAsFixed(0)}',
                      style: AppText.label(size: 9, color: AppColors.textDim),
                    ),
                  ],
                ),
                const Gap(8),
                SizedBox(
                  height: 130,
                  child: _SpeedChart(samples: trip.samples),
                ),
              ],
            ),
          ).animate(delay: 300.ms).fadeIn(),

          const Gap(12),

          // Driving events
          NeonCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EVENIMENTE', style: AppText.label(size: 10)),
                const Gap(10),
                Row(
                  children: [
                    Expanded(
                      child: _eventTile(
                        icon: Icons.fast_forward_rounded,
                        label: 'ACCELERARI',
                        count: trip.harshAccelEvents.length,
                        color: AppColors.warn,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: _eventTile(
                        icon: Icons.fast_rewind_rounded,
                        label: 'FRANARI',
                        count: trip.harshBrakeEvents.length,
                        color: AppColors.danger,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: _eventTile(
                        icon: Icons.electric_bolt_rounded,
                        label: 'MAX RPM',
                        count: trip.maxRpm.round(),
                        color: AppColors.cyan,
                        showCount: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 350.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, String unit, Color color,
      IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const Gap(4),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(size: 9.5)),
              ),
            ],
          ),
          const Gap(6),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: value, style: AppText.digital(size: 16, color: color)),
              if (unit.isNotEmpty)
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

  Widget _eventTile({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    bool showCount = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const Gap(6),
          Text(count.toString(),
              style: AppText.digital(
                  size: 18, color: color, weight: FontWeight.w900)),
          const Gap(2),
          Text(label,
              style: AppText.label(size: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Color _ecoColor(int s) {
    if (s >= 80) return AppColors.ok;
    if (s >= 60) return AppColors.cyan;
    if (s >= 40) return AppColors.warn;
    return AppColors.danger;
  }

  String _ecoLabel(int s) {
    if (s >= 90) return 'ECO MASTER';
    if (s >= 80) return 'EXCELENT';
    if (s >= 60) return 'BUN';
    if (s >= 40) return 'MEDIU';
    return 'AGRESIV';
  }

  String _ecoTip(Trip t) {
    if (t.harshBrakeEvents.length > 3) {
      return 'Anticipeaza traficul pentru a reduce franarile bruste.';
    }
    if (t.harshAccelEvents.length > 3) {
      return 'Apasa pedala progresiv — economisesti 10-15% combustibil.';
    }
    if (t.consumptionL100 > 9) {
      return 'Pastreaza turatia sub 2500 RPM in zona urbana.';
    }
    if (t.maxSpeedKmh > 140) {
      return 'Viteze peste 130 km/h cresc consumul exponential.';
    }
    return 'Stilul tau de condus este eficient. Continua tot asa!';
  }
}

/// Harta REALA cu tile-uri OpenStreetMap (stil dark CartoDB) + traseu
/// colorat dupa viteza + markeri start/finish + pin live.
///
/// Folosita doar cand trip-ul are coordonate GPS reale. Pentru moduri demo
/// fara GPS, fallback la _TripMapPainter (canvas custom).
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
    // Daca e live, urmarim pinul curent in centrul hartii.
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
    // Fallback: Suceava
    return const LatLng(47.6519, 26.2553);
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppColors.surfaceLo,
        onMapReady: () {
          // Fit-uim camera pe traseu la primul build.
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
        // Tile-uri OSM standard (consistent cu harta web)
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.obddroid.flutter',
          maxZoom: 19,
          tileProvider: NetworkTileProvider(),
        ),
        // Traseul colorat: glow sub-layer + linie peste
        if (polylinePoints.length >= 2) ...[
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 8,
                color: AppColors.cyan.withValues(alpha: 0.25),
              ),
              Polyline(
                points: polylinePoints,
                strokeWidth: 4,
                color: AppColors.cyan,
              ),
            ],
          ),
        ],
        // Markeri start, sfarsit + evenimente harsh
        MarkerLayer(
          markers: [
            if (gpsSamples.isNotEmpty)
              Marker(
                point: LatLng(
                  gpsSamples.first.lat!,
                  gpsSamples.first.lon!,
                ),
                width: 24,
                height: 24,
                child: _MapDot(
                  color: AppColors.ok,
                  label: 'S',
                ),
              ),
            // Markeri pentru evenimente brute pe parcurs
            for (final s in gpsSamples)
              if (s.accel > 3.5 || s.accel < -4.0)
                Marker(
                  point: LatLng(s.lat!, s.lon!),
                  width: 12,
                  height: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.accel > 3.5
                          ? AppColors.warn
                          : AppColors.danger,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            // Pin live (cand inregistreaza)
            if (widget.highlightLast &&
                widget.liveLat != null &&
                widget.liveLon != null)
              Marker(
                point: LatLng(widget.liveLat!, widget.liveLon!),
                width: 36,
                height: 36,
                child: _LivePin(),
              )
            else if (gpsSamples.isNotEmpty)
              // Pin final (cand trip-ul e oprit)
              Marker(
                point: LatLng(
                  gpsSamples.last.lat!,
                  gpsSamples.last.lon!,
                ),
                width: 22,
                height: 22,
                child: _MapDot(
                  color: AppColors.cyan,
                  label: 'F',
                ),
              ),
          ],
        ),
        // Attribution discret in colt
        Padding(
          padding: const EdgeInsets.all(4),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontFamily: 'Rajdhani'),
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
  final String label;
  const _MapDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
    );
  }
}

class _LivePin extends StatefulWidget {
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Cerc de impuls (puls)
            Transform.scale(
              scale: 0.6 + t * 1.4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.danger
                        .withValues(alpha: (1 - t).clamp(0, 1).toDouble()),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Pin solid
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.7),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EcoRing extends StatelessWidget {
  final int score;
  const _EcoRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.ok
        : score >= 60
            ? AppColors.cyan
            : score >= 40
                ? AppColors.warn
                : AppColors.danger;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 7,
              backgroundColor: AppColors.surfaceHi,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toString(),
                style: AppText.digital(
                    size: 22, color: color, weight: FontWeight.w900),
              ),
              Text('/100',
                  style:
                      AppText.label(size: 8, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripMapPainter extends CustomPainter {
  final List<TripSample> samples;
  final bool highlightLast;
  final bool useGps;
  _TripMapPainter({
    required this.samples,
    required this.highlightLast,
    this.useGps = false,
  });

  /// Proiectie locala equirectangular: o coord (lat,lon) → metri relativi
  /// la centrul drumului. Pe distante mici (<50 km) eroarea e neglijabila si
  /// merge mult mai natural decat Web Mercator.
  ///
  /// Returneaza pereche (x, y) in metri pe planul cartezian local.
  static (double, double) _latLonToLocalM(
      double lat, double lon, double lat0, double lon0) {
    const r = 6371000.0;
    final x = (lon - lon0) * pi / 180 * r * cos(lat0 * pi / 180);
    final y = (lat - lat0) * pi / 180 * r;
    return (x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid + compass.
    _paintGrid(canvas, size);
    _paintCompass(canvas, size);

    if (samples.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Astept date pentru harta...',
          style: TextStyle(
            color: AppColors.textDim,
            fontSize: 12,
            fontFamily: 'Rajdhani',
            letterSpacing: 1.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2));
      return;
    }

    // Construim coordonate planare. Daca avem GPS, le derivam din lat/lon
    // (proiectie equirectangular locala). Altfel folosim x/y sintetizat.
    final pts = <Offset>[];
    if (useGps) {
      // Pivot = primul sample cu GPS.
      final pivot = samples.firstWhere((s) => s.hasGps);
      final lat0 = pivot.lat!;
      final lon0 = pivot.lon!;
      double? carryX;
      double? carryY;
      for (final s in samples) {
        if (s.hasGps) {
          final (mx, my) = _latLonToLocalM(s.lat!, s.lon!, lat0, lon0);
          carryX = mx;
          carryY = my;
          pts.add(Offset(mx, my));
        } else if (carryX != null) {
          // Sample fara fix in mijlocul drumului: pastram ultima pozitie.
          pts.add(Offset(carryX, carryY!));
        } else {
          pts.add(Offset.zero);
        }
      }
    } else {
      for (final s in samples) {
        pts.add(Offset(s.x, s.y));
      }
    }

    // Bounding box pe spatiul ales (metri).
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
    final pad = 24.0;
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

    // Path glow underlay.
    final glow = Paint()
      ..color = AppColors.cyan.withOpacity(0.25)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    final first = toCanvas(0);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < samples.length; i++) {
      final p = toCanvas(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, glow);

    // Speed-graded segments.
    for (var i = 1; i < samples.length; i++) {
      final a = toCanvas(i - 1);
      final b = toCanvas(i);
      final speed = samples[i].speed;
      final color = _speedColor(speed);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
    }

    // Start marker.
    canvas.drawCircle(
      first,
      6,
      Paint()..color = AppColors.ok,
    );
    canvas.drawCircle(
      first,
      9,
      Paint()
        ..color = AppColors.ok.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // End marker (current car).
    final last = toCanvas(samples.length - 1);
    if (highlightLast) {
      canvas.drawCircle(
        last,
        9,
        Paint()..color = AppColors.danger.withValues(alpha: 0.4),
      );
    }
    canvas.drawCircle(
      last,
      5,
      Paint()..color = highlightLast ? AppColors.danger : AppColors.cyan,
    );

    // Tiny arrow showing heading at last point.
    final h = samples.last.heading;
    final tip = last + Offset(cos(h) * 14, -sin(h) * 14);
    canvas.drawLine(
      last,
      tip,
      Paint()
        ..color = highlightLast ? AppColors.danger : AppColors.cyan
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Harsh-event annotations.
    final paintHarshAccel = Paint()..color = AppColors.warn;
    final paintHarshBrake = Paint()..color = AppColors.danger;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.accel > 3.5) {
        canvas.drawCircle(toCanvas(i), 3.5, paintHarshAccel);
      } else if (s.accel < -4.0) {
        canvas.drawCircle(toCanvas(i), 3.5, paintHarshBrake);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Subtle diagonal accent
    final accent = Paint()
      ..color = AppColors.cyan.withOpacity(0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height),
        Offset(size.width, 0), accent);
  }

  void _paintCompass(Canvas canvas, Size size) {
    final cx = size.width - 28.0;
    final cy = 28.0;
    final r = 14.0;
    final ring = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), r, ring);
    final n = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: AppColors.cyan,
          fontFamily: 'Rajdhani',
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, Offset(cx - n.width / 2, cy - n.height / 2));
  }

  Color _speedColor(double v) {
    // Smooth gradient: low=cyan -> high=warn -> very high=danger
    if (v < 30) return AppColors.cyan;
    if (v < 70) return Color.lerp(AppColors.cyan, AppColors.ok, (v - 30) / 40)!;
    if (v < 110) {
      return Color.lerp(AppColors.ok, AppColors.warn, (v - 70) / 40)!;
    }
    if (v < 160) {
      return Color.lerp(AppColors.warn, AppColors.danger, (v - 110) / 50)!;
    }
    return AppColors.danger;
  }

  @override
  bool shouldRepaint(_TripMapPainter old) =>
      old.samples.length != samples.length ||
      old.highlightLast != highlightLast ||
      old.useGps != useGps;
}

class _SpeedChart extends StatelessWidget {
  final List<TripSample> samples;
  const _SpeedChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Center(
        child: Text(
          'Necesita >2 puncte',
          style: AppText.label(size: 10, color: AppColors.textDim),
        ),
      );
    }
    final t0 = samples.first.tMs;
    final spots = <FlSpot>[
      for (final s in samples)
        FlSpot((s.tMs - t0) / 1000.0, s.speed),
    ];
    final maxX = spots.last.x;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: max(60.0, samples.map((s) => s.speed).reduce(max) * 1.1),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 40,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: AppText.label(size: 8, color: AppColors.textDim),
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
                  style: AppText.label(size: 8, color: AppColors.textDim),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.18,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            color: AppColors.cyan,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.cyan.withOpacity(0.3),
                  AppColors.cyan.withOpacity(0)
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
