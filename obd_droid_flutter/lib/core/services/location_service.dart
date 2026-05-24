import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS service real folosit pentru Trip Analysis (harta live) + Voltera Fleet
/// (telemetrie cloud cu lat/lon).
///
/// Folosit de [TripProvider] cand inregistreaza un drum si de
/// [LiveDataProvider] care impinge sample-urile in [CloudSync].
class LocationService extends ChangeNotifier {
  static final LocationService I = LocationService._();
  LocationService._();

  StreamSubscription<Position>? _sub;
  Position? _last;
  bool _granted = false;
  String? _error;

  double? get lat => _last?.latitude;
  double? get lon => _last?.longitude;
  double? get speedMs => _last?.speed;
  double? get headingDeg => _last?.heading;
  double? get accuracyM => _last?.accuracy;
  bool get hasFix => _last != null;
  bool get isGranted => _granted;
  String? get error => _error;

  /// Cere permisiunea o data. Returneaza true daca utilizatorul a acordat
  /// "while-in-use" sau "always".
  Future<bool> ensurePermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      _error = 'GPS dezactivat in setarile telefonului';
      notifyListeners();
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      _error = 'Permisiune GPS refuzata permanent. Activeaza din Setari.';
      _granted = false;
      notifyListeners();
      return false;
    }
    _granted = p == LocationPermission.whileInUse || p == LocationPermission.always;
    _error = _granted ? null : 'Permisiune GPS lipsa';
    notifyListeners();
    return _granted;
  }

  /// Porneste stream-ul de pozitii. Apeleaza dupa ensurePermission().
  Future<void> start() async {
    if (_sub != null) return;
    final ok = await ensurePermission();
    if (!ok) return;
    try {
      _last = await Geolocator.getLastKnownPosition();
    } catch (_) {/* ignore */}
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        _last = pos;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
