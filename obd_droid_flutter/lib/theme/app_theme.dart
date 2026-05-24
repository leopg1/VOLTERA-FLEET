import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium automotive dark theme. **Single accent**: cyan #00D4FF.
/// Status colors (green/orange/red) sunt folosite EXCLUSIV pentru a indica
/// stari OBD (ok/warning/critical) — nu pentru decor.
///
/// Tot textul foloseste Orbitron pentru valori numerice si Rajdhani pentru
/// label-uri/body. Fonturile sunt bundled in assets/fonts/ si servite prin
/// `google_fonts` — `allowRuntimeFetching = false` in main(), 100% offline.
class AppColors {
  // Background & surfaces
  static const bg = Color(0xFF07090F);
  static const surface = Color(0xFF0D1117);
  static const surfaceHi = Color(0xFF131A22);
  static const surfaceLo = Color(0xFF0A0D14);

  // Subtle borders
  static const border = Color(0x1FFFFFFF); // 12% white
  static const borderHi = Color(0x33FFFFFF); // 20% white

  // Single accent
  static const cyan = Color(0xFF00D4FF);
  static const cyanGlow = Color(0x6600D4FF);
  static const cyanDeep = Color(0xFF0091B8);

  // OBD status semantics (used only for status, never decoration)
  static const ok = Color(0xFF00E676);
  static const warn = Color(0xFFFFAB00);
  static const danger = Color(0xFFFF1744);

  // Text
  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF8892A4);
  static const textDim = Color(0xFF4A5260);

  // Gradients
  static const cyanGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0091B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF131A22), Color(0xFF0D1117)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Back-compat aliases (vechi screens). Toate decorative trec pe cyan.
  static const accent = cyan;
  static const accentDeep = cyanDeep;
  static const orange = cyan;
  static const red = danger;
  static const green = ok;
  static const yellow = warn;
  static const stroke = border;
  static const primary = cyan;
  static const gradientCyan = cyanGradient;
  static const gradientOrange = cyanGradient;
  static const gradientRed = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Typography helpers — Orbitron pentru numere, Rajdhani pentru text.
/// Fonturile sunt declarate ca asset families in pubspec.yaml (Orbitron e
/// font variable mapat la toate weight-urile, Rajdhani e static per weight).
class AppText {
  AppText._();

  static const String orbitron = 'Orbitron';
  static const String rajdhani = 'Rajdhani';

  /// Orbitron — Industrial, futuristic. Numerical values, gauge centers.
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

  /// Rajdhani — Clean, technical. Labels, captions, uppercase chips.
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

  /// Body — running text, descriptions.
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

  /// Title — Rajdhani Bold for screen headers.
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

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        onPrimary: Colors.black,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.surface,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppText.title(size: 18),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: Colors.black,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.label(
            size: 13,
            color: Colors.black,
            weight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.borderHi),
          foregroundColor: AppColors.cyan,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
          textStyle:
              AppText.label(color: AppColors.cyan, weight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.4),
        ),
        labelStyle: AppText.body(color: AppColors.textMuted, size: 14),
        hintStyle: AppText.body(color: AppColors.textDim, size: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.text,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: AppColors.surfaceHi,
      ),
      iconTheme: const IconThemeData(color: AppColors.text),
      textTheme: base.textTheme.apply(
        fontFamily: AppText.rajdhani,
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    );
  }
}
