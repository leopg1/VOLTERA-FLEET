import 'package:flutter/material.dart';

import 'colors.dart';

/// Voltera type scale. Inter pentru UI, JetBrains Mono pentru numere live.
/// Max 4 size-uri pe ecran. Letter-spacing 0 peste tot, exceptand label/11
/// care e singurul ALL CAPS din sistem.
class VType {
  VType._();

  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  // ----- Display (hero metrics, screen heroes) -----
  static const TextStyle display72 = TextStyle(
    fontFamily: mono,
    fontSize: 64, // 72 e ideal pe tableta; pe phone scalam responsive
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: VColors.textStrong,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle display40 = TextStyle(
    fontFamily: sans,
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: VColors.textStrong,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ----- Titles -----
  static const TextStyle title24 = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: VColors.textStrong,
  );

  static const TextStyle title18 = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    color: VColors.textStrong,
  );

  // ----- Body -----
  static const TextStyle body15 = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
    color: VColors.textDefault,
  );

  static const TextStyle body13 = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 19 / 13,
    fontWeight: FontWeight.w500,
    color: VColors.textDefault,
  );

  // ----- Label (only ALL CAPS in the system) -----
  static const TextStyle label11 = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
    color: VColors.textMuted,
  );

  // ----- Inline mono numeric -----
  static const TextStyle mono15 = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    color: VColors.textStrong,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle mono13 = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: VColors.textDefault,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
