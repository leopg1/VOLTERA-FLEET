import 'package:flutter/foundation.dart';

@immutable
class Vehicle {
  final String? vin;
  final String? make;
  final String? model;
  final int? year;
  final String? trim;
  final String? engine;
  final String? fuelType;
  final String? transmission;
  final String? bodyClass;
  final String? plant;
  final List<String> ecuAddresses;
  final DateTime? lastSeen;

  const Vehicle({
    this.vin,
    this.make,
    this.model,
    this.year,
    this.trim,
    this.engine,
    this.fuelType,
    this.transmission,
    this.bodyClass,
    this.plant,
    this.ecuAddresses = const [],
    this.lastSeen,
  });

  String get displayName {
    final parts = <String>[];
    if (year != null) parts.add('$year');
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    return parts.isEmpty ? 'Unknown vehicle' : parts.join(' ');
  }

  bool get hasVin => vin != null && vin!.length == 17;

  Vehicle copyWith({
    String? vin,
    String? make,
    String? model,
    int? year,
    String? trim,
    String? engine,
    String? fuelType,
    String? transmission,
    String? bodyClass,
    String? plant,
    List<String>? ecuAddresses,
    DateTime? lastSeen,
  }) {
    return Vehicle(
      vin: vin ?? this.vin,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      trim: trim ?? this.trim,
      engine: engine ?? this.engine,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      bodyClass: bodyClass ?? this.bodyClass,
      plant: plant ?? this.plant,
      ecuAddresses: ecuAddresses ?? this.ecuAddresses,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'vin': vin,
        'make': make,
        'model': model,
        'year': year,
        'trim': trim,
        'engine': engine,
        'fuelType': fuelType,
        'transmission': transmission,
        'bodyClass': bodyClass,
        'plant': plant,
        'ecuAddresses': ecuAddresses,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        vin: json['vin'] as String?,
        make: json['make'] as String?,
        model: json['model'] as String?,
        year: json['year'] as int?,
        trim: json['trim'] as String?,
        engine: json['engine'] as String?,
        fuelType: json['fuelType'] as String?,
        transmission: json['transmission'] as String?,
        bodyClass: json['bodyClass'] as String?,
        plant: json['plant'] as String?,
        ecuAddresses:
            (json['ecuAddresses'] as List?)?.cast<String>() ?? const [],
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String)
            : null,
      );
}
