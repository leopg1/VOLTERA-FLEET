import 'package:flutter/material.dart';

/// Raw palette. Niciun widget nu citeste de aici direct in afara theme-ului
/// si a [VolteraTokens]. Tot ce inseamna semantic ("surface", "border")
/// trece prin ThemeExtension.
class VColors {
  VColors._();

  // ----- Ink scale (canvas + surfaces) -----
  static const ink950 = Color(0xFF06080C);
  static const ink900 = Color(0xFF0B0F15);
  static const ink800 = Color(0xFF121822);
  static const ink700 = Color(0xFF1B2330);
  static const ink600 = Color(0xFF2A3343);

  // ----- Hairlines -----
  static const hairline = Color(0x0FFFFFFF); // ~6% white
  static const hairlineStrong = Color(0x1AFFFFFF); // ~10%

  // ----- Single primary accent — "Voltera Blue" -----
  static const accent500 = Color(0xFF4F86FF);
  static const accent600 = Color(0xFF2E63E6);
  static const accent200 = Color(0xFFB9CDFF);
  static const accentOnDark = Color(0xFF06080C); // text pe fundal accent

  // ----- Semantic colors — folosite EXCLUSIV pentru status -----
  static const ok500 = Color(0xFF1FB67A);
  static const warn500 = Color(0xFFE0A019);
  static const danger500 = Color(0xFFE5484D);

  // ----- Text scale -----
  static const textStrong = Color(0xFFF2F4F7);
  static const textDefault = Color(0xFFC9CFD9);
  static const textMuted = Color(0xFF7C8696);
  static const textDisabled = Color(0xFF4B5364);
}
