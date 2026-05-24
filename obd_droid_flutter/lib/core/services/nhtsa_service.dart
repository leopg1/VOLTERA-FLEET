import 'package:dio/dio.dart';

import '../models/vehicle.dart';

/// Wraps the public NHTSA APIs:
/// - VIN decode  → https://vpic.nhtsa.dot.gov/api/
/// - Recalls     → https://api.nhtsa.gov/recalls/recallsByVehicle
class NhtsaService {
  final Dio _dio;

  NhtsaService([Dio? dio]) : _dio = dio ?? Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 15);

  /// Decode a VIN into make/model/year/trim metadata.
  Future<Vehicle> decodeVin(String vin) async {
    final r = await _dio.get<Map<String, dynamic>>(
      'https://vpic.nhtsa.dot.gov/api/vehicles/decodevin/$vin',
      queryParameters: {'format': 'json'},
    );
    final results = (r.data?['Results'] as List?) ?? const [];
    String? pull(String key) {
      for (final item in results) {
        if (item is Map && item['Variable'] == key) {
          final v = item['Value'];
          if (v is String && v.trim().isNotEmpty) return v;
        }
      }
      return null;
    }

    return Vehicle(
      vin: vin,
      make: pull('Make'),
      model: pull('Model'),
      year: int.tryParse(pull('Model Year') ?? ''),
      trim: pull('Trim'),
      engine: pull('Engine Model') ?? pull('Displacement (L)'),
      fuelType: pull('Fuel Type - Primary'),
      transmission: pull('Transmission Style'),
      bodyClass: pull('Body Class'),
      plant: pull('Plant Country'),
      lastSeen: DateTime.now(),
    );
  }

  /// Returns open recalls for a vehicle.
  Future<List<NhtsaRecall>> recalls({
    required int year,
    required String make,
    required String model,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      'https://api.nhtsa.gov/recalls/recallsByVehicle',
      queryParameters: {
        'make': make,
        'model': model,
        'modelYear': year,
      },
    );
    final results = (r.data?['results'] as List?) ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(NhtsaRecall.fromJson)
        .toList();
  }
}

class NhtsaRecall {
  final String campaign;
  final String component;
  final String summary;
  final String consequence;
  final String remedy;
  final DateTime? reportDate;

  NhtsaRecall({
    required this.campaign,
    required this.component,
    required this.summary,
    required this.consequence,
    required this.remedy,
    this.reportDate,
  });

  factory NhtsaRecall.fromJson(Map<String, dynamic> j) => NhtsaRecall(
        campaign: (j['NHTSACampaignNumber'] ?? '').toString(),
        component: (j['Component'] ?? '').toString(),
        summary: (j['Summary'] ?? '').toString(),
        consequence: (j['Consequence'] ?? '').toString(),
        remedy: (j['Remedy'] ?? '').toString(),
        reportDate: DateTime.tryParse((j['ReportReceivedDate'] ?? '').toString()),
      );
}
