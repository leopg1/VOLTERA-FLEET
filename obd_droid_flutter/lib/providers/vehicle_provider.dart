import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/vehicle.dart';
import '../core/obd/obd_service.dart';
import '../core/services/nhtsa_service.dart';

class VehicleProvider extends ChangeNotifier {
  Vehicle? _vehicle;
  bool _decoding = false;
  String? _error;

  final NhtsaService _nhtsa;

  VehicleProvider({NhtsaService? nhtsa}) : _nhtsa = nhtsa ?? NhtsaService();

  Vehicle? get vehicle => _vehicle;
  bool get isDecoding => _decoding;
  String? get error => _error;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vehicle');
    if (raw != null) {
      try {
        _vehicle =
            Vehicle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {/* corrupt cache, ignore */}
    }
  }

  Future<void> refreshFromVin(String vin) async {
    _decoding = true;
    _error = null;
    notifyListeners();
    try {
      _vehicle = await _nhtsa.decodeVin(vin);
      await _persist();
    } catch (e) {
      _error = e.toString();
    } finally {
      _decoding = false;
      notifyListeners();
    }
  }

  Future<void> readVinFromVehicle(ObdService service) async {
    final vin = await service.readVin();
    if (vin != null) await refreshFromVin(vin);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_vehicle == null) {
      await prefs.remove('vehicle');
    } else {
      await prefs.setString('vehicle', jsonEncode(_vehicle!.toJson()));
    }
  }
}
