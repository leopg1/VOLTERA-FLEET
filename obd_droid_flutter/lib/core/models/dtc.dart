import 'package:flutter/foundation.dart';

/// Diagnostic Trouble Code severity classification.
enum DtcSeverity { confirmed, pending, permanent, history }

/// Diagnostic Trouble Code category derived from the first letter.
enum DtcCategory {
  powertrain('P', 'Powertrain'),
  body('B', 'Body'),
  chassis('C', 'Chassis'),
  network('U', 'Network');

  final String letter;
  final String label;
  const DtcCategory(this.letter, this.label);

  static DtcCategory fromLetter(String l) {
    return DtcCategory.values.firstWhere(
      (c) => c.letter == l.toUpperCase(),
      orElse: () => DtcCategory.powertrain,
    );
  }
}

@immutable
class Dtc {
  final String code;          // e.g. "P0301"
  final DtcSeverity severity;
  final DtcCategory category;
  final String description;
  final String? remedy;
  final String? consequence;
  final String? ecu;
  final DateTime detectedAt;

  const Dtc({
    required this.code,
    required this.severity,
    required this.category,
    required this.description,
    this.remedy,
    this.consequence,
    this.ecu,
    required this.detectedAt,
  });

  bool get isManufacturerSpecific {
    if (code.length < 2) return false;
    final secondChar = code[1];
    return secondChar == '1' || secondChar == '3';
  }

  /// Decode raw 4-character hex into a P/B/C/U code.
  /// Bytes layout: AAAA where first 2 bits = letter, next 2 bits = digit, then 12 bits.
  static String decodeRaw(int hi, int lo) {
    final letterBits = (hi & 0xC0) >> 6;
    const letterMap = {0: 'P', 1: 'C', 2: 'B', 3: 'U'};
    final letter = letterMap[letterBits] ?? 'P';

    final firstDigit = (hi & 0x30) >> 4;
    final secondDigit = (hi & 0x0F);
    final loHex = lo.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$letter$firstDigit${secondDigit.toRadixString(16).toUpperCase()}$loHex';
  }
}
