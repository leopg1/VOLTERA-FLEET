import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/obd/obd_service.dart';
import '../core/services/cloud_sync.dart';
import '../core/services/location_service.dart';
import 'live_data_provider.dart';

/// A single sample inside a trip — captures kinematics and key engine vars.
/// Cand GPS-ul e disponibil, [lat]/[lon] sunt non-null si harta deseneaza
/// drumul real. Cand nu e (mod demo / fara permisiune), folosim x/y sintetizat.
@immutable
class TripSample {
  final int tMs;
  final double speed;        // km/h
  final double rpm;
  final double throttle;     // 0..100 (%)
  final double coolant;
  final double engineLoad;   // 0..100 (%)
  final double maf;          // g/s
  final double x;            // synthesized 2D plane (meters)
  final double y;
  final double heading;      // radians
  final double accel;        // m/s^2 (instantaneous)
  final double? lat;         // grade decimale (null = fara GPS)
  final double? lon;
  final double? gpsAccuracy; // metri (precizia raportata de GPS)

  const TripSample({
    required this.tMs,
    required this.speed,
    required this.rpm,
    required this.throttle,
    required this.coolant,
    required this.engineLoad,
    required this.maf,
    required this.x,
    required this.y,
    required this.heading,
    required this.accel,
    this.lat,
    this.lon,
    this.gpsAccuracy,
  });

  bool get hasGps => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
        't': tMs,
        'sp': speed,
        'rp': rpm,
        'th': throttle,
        'co': coolant,
        'el': engineLoad,
        'mf': maf,
        'x': x,
        'y': y,
        'h': heading,
        'a': accel,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (gpsAccuracy != null) 'ga': gpsAccuracy,
      };

  factory TripSample.fromJson(Map<String, dynamic> j) => TripSample(
        tMs: (j['t'] as num).toInt(),
        speed: (j['sp'] as num).toDouble(),
        rpm: (j['rp'] as num).toDouble(),
        throttle: (j['th'] as num).toDouble(),
        coolant: (j['co'] as num).toDouble(),
        engineLoad: (j['el'] as num).toDouble(),
        maf: (j['mf'] as num).toDouble(),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        heading: (j['h'] as num).toDouble(),
        accel: (j['a'] as num).toDouble(),
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        gpsAccuracy: (j['ga'] as num?)?.toDouble(),
      );
}

/// A recorded driving session.
class Trip {
  final String id;
  final DateTime startedAt;
  DateTime endedAt;
  final List<TripSample> samples;
  final List<Duration> harshAccelEvents;
  final List<Duration> harshBrakeEvents;
  String? notes;

  Trip({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.samples,
    List<Duration>? harshAccelEvents,
    List<Duration>? harshBrakeEvents,
    this.notes,
  })  : harshAccelEvents = harshAccelEvents ?? [],
        harshBrakeEvents = harshBrakeEvents ?? [];

  Duration get duration => endedAt.difference(startedAt);

  /// True daca cel putin jumatate din sample-uri au coordonate GPS reale.
  bool get hasGpsTrack {
    if (samples.isEmpty) return false;
    final gpsCount = samples.where((s) => s.hasGps).length;
    return gpsCount >= samples.length ~/ 2;
  }

  /// Total distance in km. Preferam GPS (haversine) cand exista,
  /// altfel cadem pe kinematic (x/y sintetizat).
  double get distanceKm {
    if (samples.length < 2) return 0;
    if (hasGpsTrack) {
      double meters = 0;
      TripSample? prev;
      for (final s in samples) {
        if (s.hasGps && prev != null && prev.hasGps) {
          meters += _haversine(prev.lat!, prev.lon!, s.lat!, s.lon!);
        }
        if (s.hasGps) prev = s;
      }
      return meters / 1000.0;
    }
    double meters = 0;
    for (var i = 1; i < samples.length; i++) {
      final dx = samples[i].x - samples[i - 1].x;
      final dy = samples[i].y - samples[i - 1].y;
      meters += sqrt(dx * dx + dy * dy);
    }
    return meters / 1000.0;
  }

  /// Haversine distance intre doua coordonate GPS, in metri.
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // raza Pamant
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double get avgSpeedKmh =>
      samples.isEmpty ? 0 : samples.map((s) => s.speed).reduce((a, b) => a + b) / samples.length;

  double get maxSpeedKmh =>
      samples.isEmpty ? 0 : samples.map((s) => s.speed).reduce((a, b) => a > b ? a : b);

  double get maxRpm =>
      samples.isEmpty ? 0 : samples.map((s) => s.rpm).reduce((a, b) => a > b ? a : b);

  double get maxAccelMs2 => samples.isEmpty
      ? 0
      : samples.map((s) => s.accel.abs()).reduce((a, b) => a > b ? a : b);

  /// Estimated fuel consumption in liters using MAF integral
  /// (0.0805 g/s gas/AFR = 14.7 air, 750 g/L petrol density).
  double get fuelLiters {
    if (samples.length < 2) return 0;
    double grams = 0;
    for (var i = 1; i < samples.length; i++) {
      final dt = (samples[i].tMs - samples[i - 1].tMs) / 1000.0;
      final airGs = (samples[i].maf + samples[i - 1].maf) / 2;
      // air -> fuel via stoichiometric AFR ~= 14.7 (gasoline)
      final fuelGs = airGs / 14.7;
      grams += fuelGs * dt;
    }
    return grams / 750.0; // ~750 g/L petrol
  }

  /// L/100km — main consumption metric used in EU.
  double get consumptionL100 {
    final d = distanceKm;
    if (d < 0.05) return 0;
    return fuelLiters / d * 100;
  }

  /// CO2 estimate in kg, ~2.31 kg/L petrol.
  double get co2Kg => fuelLiters * 2.31;

  /// Eco score 0..100. Higher is greener.
  /// Penalizes harsh accel/brake, high RPM averages, and overconsumption.
  int get ecoScore {
    if (samples.length < 5) return 100;
    final avgRpm =
        samples.map((s) => s.rpm).reduce((a, b) => a + b) / samples.length;
    final harsh = harshAccelEvents.length + harshBrakeEvents.length;
    final consPenalty = (consumptionL100 - 7).clamp(0, 12) * 3;
    final rpmPenalty = ((avgRpm - 2200).clamp(0, 3000) / 3000) * 25;
    final harshPenalty = (harsh * 4).clamp(0, 30);
    final raw = 100 - consPenalty - rpmPenalty - harshPenalty;
    return raw.clamp(0, 100).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'notes': notes,
        'harshAccel': harshAccelEvents.map((d) => d.inMilliseconds).toList(),
        'harshBrake': harshBrakeEvents.map((d) => d.inMilliseconds).toList(),
        'samples': samples.map((s) => s.toJson()).toList(),
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        samples: (j['samples'] as List)
            .cast<Map<String, dynamic>>()
            .map(TripSample.fromJson)
            .toList(),
        harshAccelEvents: (j['harshAccel'] as List?)
                ?.cast<num>()
                .map((m) => Duration(milliseconds: m.toInt()))
                .toList() ??
            [],
        harshBrakeEvents: (j['harshBrake'] as List?)
                ?.cast<num>()
                .map((m) => Duration(milliseconds: m.toInt()))
                .toList() ??
            [],
        notes: j['notes'] as String?,
      );
}

/// Records active trips and persists them to SharedPreferences.
///
/// Without real GPS we synthesize a 2D path using the integral of speed
/// vector projected on a heading that "drifts" gently with throttle/steering
/// proxy (acceleration). This produces an organic, road-like trace suitable
/// for visualization on a stylized map.
class TripProvider extends ChangeNotifier {
  static const _kStorageKey = 'trips_v1';
  static const _kMaxTrips = 30;

  Trip? _activeTrip;
  Timer? _ticker;
  final List<Trip> _saved = [];
  final Random _rng = Random();
  double _lastSpeed = 0;
  int _lastTickMs = 0;
  double _heading = 0;
  double _x = 0;
  double _y = 0;

  Trip? get activeTrip => _activeTrip;
  bool get isRecording => _activeTrip != null;
  List<Trip> get saved => List.unmodifiable(_saved);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _saved
        ..clear()
        ..addAll(list.map(Trip.fromJson));
      notifyListeners();
    } catch (_) {/* ignore corrupt cache */}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _saved.map((t) => t.toJson()).toList();
    await prefs.setString(_kStorageKey, jsonEncode(list));
  }

  /// Start a new trip session. Pulls live samples via [live].
  /// Daca utilizatorul a acordat permisiune GPS, capteaza si lat/lon real.
  void startTrip(LiveDataProvider live, {ObdService? service}) {
    if (_activeTrip != null) return;
    final id = 't_${DateTime.now().millisecondsSinceEpoch}';
    _activeTrip = Trip(
      id: id,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      samples: [],
    );
    _lastSpeed = 0;
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;
    _heading = _rng.nextDouble() * pi * 2;
    _x = 0;
    _y = 0;

    // Porneste GPS-ul in background. Daca user-ul refuza permisiunea,
    // _captureSample va fallback la traseu cinematic sintetizat.
    LocationService.I.start();

    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _captureSample(live);
    });

    // Notifica cloud-ul (Voltera Fleet). Tagheaza sample-urile cu trip_id.
    CloudSync.I.startTrip();

    notifyListeners();
  }

  void _captureSample(LiveDataProvider live) {
    final t = _activeTrip;
    if (t == null) return;
    final now = DateTime.now();
    final tMs = now.millisecondsSinceEpoch;

    final speed = live.latest[0x0D]?.value ?? 0.0;
    final rpm = live.latest[0x0C]?.value ?? 0.0;
    final throttle = live.latest[0x11]?.value ?? 0.0;
    final coolant = live.latest[0x05]?.value ?? 0.0;
    final load = live.latest[0x04]?.value ?? 0.0;
    final maf = live.latest[0x10]?.value ?? 0.0;

    final dtMs = (tMs - _lastTickMs).clamp(1, 5000);
    final dt = dtMs / 1000.0;
    final dvMs = (speed - _lastSpeed) / 3.6; // delta speed in m/s
    final accel = dvMs / dt;

    // GPS fix daca exista. Heading-ul vine din GPS daca avem fix valid,
    // altfel pastram heading sintetizat.
    final gps = LocationService.I;
    final hasGps = gps.hasFix && gps.isGranted;
    if (hasGps && gps.headingDeg != null && gps.speedMs != null && gps.speedMs! > 1) {
      // GPS heading e in grade [0..360], 0=N, 90=E. Convertim la radiani
      // si la conventia matematica (0=E, sens trigonometric) pentru consistenta
      // cu painter-ul existent.
      _heading = (90 - gps.headingDeg!) * pi / 180;
    } else {
      _heading += (_rng.nextDouble() - 0.5) * 0.06;
      if (accel.abs() < 0.5 && rpm > 1500) {
        _heading += (_rng.nextDouble() - 0.5) * 0.025;
      }
    }

    final speedMs = speed / 3.6;
    _x += cos(_heading) * speedMs * dt;
    _y += sin(_heading) * speedMs * dt;

    final sample = TripSample(
      tMs: tMs,
      speed: speed,
      rpm: rpm,
      throttle: throttle,
      coolant: coolant,
      engineLoad: load,
      maf: maf,
      x: _x,
      y: _y,
      heading: _heading,
      accel: accel,
      lat: hasGps ? gps.lat : null,
      lon: hasGps ? gps.lon : null,
      gpsAccuracy: hasGps ? gps.accuracyM : null,
    );

    t.samples.add(sample);
    t.endedAt = now;

    // Detect harsh events.
    if (accel > 3.5) t.harshAccelEvents.add(now.difference(t.startedAt));
    if (accel < -4.0) t.harshBrakeEvents.add(now.difference(t.startedAt));

    _lastSpeed = speed;
    _lastTickMs = tMs;

    notifyListeners();
  }

  Future<Trip?> stopTrip() async {
    final t = _activeTrip;
    _ticker?.cancel();
    _ticker = null;
    _activeTrip = null;
    await LocationService.I.stop();
    if (t == null) {
      notifyListeners();
      return null;
    }
    if (t.samples.isNotEmpty) {
      _saved.insert(0, t);
      while (_saved.length > _kMaxTrips) {
        _saved.removeLast();
      }
      await _persist();
    }

    // Inchide trip-ul in cloud cu agregatele finale.
    await CloudSync.I.endTrip(
      distanceKm: t.distanceKm,
      fuelL: t.fuelLiters,
      maxSpeedKmh: t.maxSpeedKmh,
      maxRpm: t.maxRpm,
      ecoScore: t.ecoScore,
    );

    notifyListeners();
    return t;
  }

  Future<void> deleteTrip(String id) async {
    _saved.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _saved.clear();
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
