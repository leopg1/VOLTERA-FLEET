import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Cloud sync layer pentru Voltera Fleet.
///
/// Responsabilitati:
///  - Initializare client Supabase (URL + anon key din SharedPreferences/env)
///  - Buffereaza sample-uri local si le urca batch la fiecare [flushIntervalMs]
///  - Re-incearca la urmatorul tick daca pica reteaua
///  - Trimite evenimente (DTC, harsh brake, etc.) imediat
///
/// Configurare: vezi `FleetConfig` mai jos. Pentru demo academic, foloseste
/// anon key — pentru productie, ai nevoie de JWT per device.
class CloudSync {
  static final CloudSync I = CloudSync._();
  CloudSync._();

  SupabaseClient? _client;
  bool get isEnabled => _client != null && _vehicleId != null;

  String? _vehicleId;
  String? get vehicleId => _vehicleId;

  String? _activeTripId;
  String? get activeTripId => _activeTripId;

  final Queue<Map<String, dynamic>> _buffer = Queue();
  Timer? _flushTimer;
  static const int flushIntervalMs = 3000;
  static const int maxBufferSize = 500;

  int totalUploaded = 0;
  int failedUploads = 0;
  DateTime? lastFlushAt;
  String? lastError;

  /// Initializeaza din SharedPreferences. Apeleaza in `main()` dupa
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('fleet.supabaseUrl');
    final key = prefs.getString('fleet.supabaseAnonKey');
    _vehicleId = prefs.getString('fleet.vehicleId');

    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      if (kDebugMode) print('[CloudSync] disabled — no URL/key set');
      return;
    }
    try {
      await Supabase.initialize(url: url, anonKey: key);
      _client = Supabase.instance.client;
      _startFlushTimer();
      if (kDebugMode) print('[CloudSync] initialized, vehicleId=$_vehicleId');
    } catch (e) {
      lastError = e.toString();
      if (kDebugMode) print('[CloudSync] init failed: $e');
    }
  }

  /// Reconfigurare runtime — apeleaza din ecranul de setari Fleet.
  Future<void> configure({
    required String url,
    required String anonKey,
    required String vehicleId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fleet.supabaseUrl', url);
    await prefs.setString('fleet.supabaseAnonKey', anonKey);
    await prefs.setString('fleet.vehicleId', vehicleId);

    try {
      if (_client == null) {
        await Supabase.initialize(url: url, anonKey: anonKey);
      }
      _client = Supabase.instance.client;
    } catch (e) {
      lastError = e.toString();
    }
    _vehicleId = vehicleId;
    _startFlushTimer();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: flushIntervalMs),
      (_) => _flush(),
    );
  }

  // ============================================================
  // TELEMETRY
  // ============================================================

  /// Coada un sample. Apeleaza din `LiveDataProvider._tick`.
  void enqueueSample({
    required double? lat,
    required double? lon,
    required double? speedKmh,
    required double? rpm,
    required double? coolant,
    required double? throttle,
    required double? engineLoad,
    required double? maf,
    required double? battery,
    required double? fuelPct,
    required double? intakeAirTemp,
    required double? mapKpa,
  }) {
    if (!isEnabled) return;
    _buffer.add({
      'vehicle_id': _vehicleId,
      'trip_id': _activeTripId,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (rpm != null) 'rpm': rpm,
      if (coolant != null) 'coolant': coolant,
      if (throttle != null) 'throttle': throttle,
      if (engineLoad != null) 'engine_load': engineLoad,
      if (maf != null) 'maf': maf,
      if (battery != null) 'battery': battery,
      if (fuelPct != null) 'fuel_pct': fuelPct,
      if (intakeAirTemp != null) 'intake_air_temp': intakeAirTemp,
      if (mapKpa != null) 'map_kpa': mapKpa,
    });
    if (_buffer.length > maxBufferSize) {
      _buffer.removeFirst();
    }
  }

  Future<void> _flush() async {
    if (!isEnabled || _buffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      await _client!.from('telemetry_samples').insert(batch);
      totalUploaded += batch.length;
      lastFlushAt = DateTime.now();
    } catch (e) {
      failedUploads += batch.length;
      lastError = e.toString();
      // Pune-le inapoi in coada (front)
      for (final s in batch.reversed) {
        _buffer.addFirst(s);
      }
      if (kDebugMode) print('[CloudSync] flush failed: $e');
    }
  }

  // ============================================================
  // TRIP LIFECYCLE
  // ============================================================

  Future<String?> startTrip({String? driverName}) async {
    if (!isEnabled) return null;
    final tripId = const Uuid().v4();
    try {
      await _client!.from('trips').insert({
        'id': tripId,
        'vehicle_id': _vehicleId,
        'driver_name': driverName,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
      _activeTripId = tripId;
      return tripId;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<void> endTrip({
    double? distanceKm,
    double? fuelL,
    double? maxSpeedKmh,
    double? maxRpm,
    int? ecoScore,
  }) async {
    if (!isEnabled || _activeTripId == null) return;
    try {
      await _client!.from('trips').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        if (distanceKm != null) 'distance_km': distanceKm,
        if (fuelL != null) 'fuel_l': fuelL,
        if (maxSpeedKmh != null) 'max_speed_kmh': maxSpeedKmh,
        if (maxRpm != null) 'max_rpm': maxRpm,
        if (ecoScore != null) 'eco_score': ecoScore,
      }).eq('id', _activeTripId!);
    } catch (e) {
      lastError = e.toString();
    } finally {
      _activeTripId = null;
    }
  }

  // ============================================================
  // EVENTS (DTC, harsh brake, alerte)
  // ============================================================

  Future<void> sendEvent({
    required String type,
    required String severity,
    required String title,
    String? code,
    String? description,
    Map<String, dynamic>? payload,
  }) async {
    if (!isEnabled) return;
    try {
      await _client!.from('events').insert({
        'vehicle_id': _vehicleId,
        'trip_id': _activeTripId,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'type': type,
        'severity': severity,
        if (code != null) 'code': code,
        'title': title,
        if (description != null) 'description': description,
        if (payload != null) 'payload': payload,
      });
    } catch (e) {
      lastError = e.toString();
      if (kDebugMode) print('[CloudSync] event failed: $e');
    }
  }

  Future<void> upsertVehicleMeta({
    required String plate,
    String? vin,
    String? make,
    String? model,
    int? year,
    String? driverName,
    String? color,
  }) async {
    if (!isEnabled) return;
    try {
      await _client!.from('vehicles').upsert({
        'id': _vehicleId,
        'plate': plate,
        if (vin != null) 'vin': vin,
        if (make != null) 'make': make,
        if (model != null) 'model': model,
        if (year != null) 'year': year,
        if (driverName != null) 'driver_name': driverName,
        if (color != null) 'color': color,
      });
    } catch (e) {
      lastError = e.toString();
    }
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}
