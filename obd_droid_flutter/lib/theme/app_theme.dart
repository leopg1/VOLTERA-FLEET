import 'package:flutter/material.dart';

import '../design/theme/voltera_theme.dart';
import '../design/tokens/colors.dart';

/// SHIM back-compat. Vechiul API ramane (AppColors / AppText / AppTheme)
/// dar valorile vin din noul design system. Pe masura ce ecranele se
/// refactoreaza la VColors / VType / context.tokens, simbolurile de aici
/// se elimina treptat. Acest fisier va disparea complet la finalul migrarii.
///
/// Reguli pentru cod nou:
///  - NU folositi AppColors / AppText in cod nou.
///  - Folositi `context.tokens.x` pentru culori si VType pentru text.
class AppColors {
  AppColors._();

  // Surfaces (mapate la noul ink scale)
  static const Color bg = VColors.ink950;
  static const Color surface = VColors.ink900;
  static const Color surfaceHi = VColors.ink800;
  static const Color surfaceLo = VColors.ink950;

  // Borders
  static const Color border = VColors.hairline;
  static const Color borderHi = VColors.hairlineStrong;

  // Old "cyan" → noul accent Voltera Blue
  static const Color cyan = VColors.accent500;
  static const Color cyanGlow = Color(0x664F86FF);
  static const Color cyanDeep = VColors.accent600;

  // Semantic — neschimbate logic, valori actualizate la noul scale
  static const Color ok = VColors.ok500;
  static const Color warn = VColors.warn500;
  static const Color danger = VColors.danger500;

  // Text
  static const Color text = VColors.textStrong;
  static const Color textMuted = VColors.textMuted;
  static const Color textDim = VColors.textDisabled;

  // Gradients (pastrate pentru ecranele vechi; in noul sistem se evita)
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [VColors.accent500, VColors.accent600],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [VColors.ink800, VColors.ink900],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Aliasuri istorice — toate pe accent
  static const Color accent = cyan;
  static const Color accentDeep = cyanDeep;
  static const Color orange = cyan;
  static const Color red = danger;
  static const Color green = ok;
  static const Color yellow = warn;
  static const Color stroke = border;
  static const Color primary = cyan;
  static const LinearGradient gradientCyan = cyanGradient;
  static const LinearGradient gradientOrange = cyanGradient;
  static const LinearGradient gradientRed = LinearGradient(
    colors: [VColors.danger500, Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Helpers tipografice istorice. Numerele vechi vor continua sa randeze
/// cu Orbitron / Rajdhani pana cand ecranul respectiv migreaza la VType.
class AppText {
  AppText._();

  static const String orbitron = 'Orbitron';
  static const String rajdhani = 'Rajdhani';

  static TextStyle digital({
    double size = 32,
    Color color = AppColors.cyan,
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 0.8,
  }) =>
      TextStyle(
        fontFamily: orbitron,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.05,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle label({
    double size = 11,
    Color color = AppColors.textMuted,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 1.6,
  }) =>
      TextStyle(
        fontFamily: rajdhani,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.1,
      );

  static TextStyle body({
    double size = 14,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: rajdhani,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 0.2,
        height: 1.35,
      );

  static TextStyle title({
    double size = 20,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: rajdhani,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 0.6,
      );
}

/// Shim — toate apelurile la AppTheme.dark() returneaza acum noul tema Voltera.
class AppTheme {
  AppTheme._();
  static ThemeData dark() => VolteraTheme.dark();
}
