import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/elevation.dart';

/// Tokens semantici expusi prin Theme. Widget-urile citesc culorile prin
/// `context.tokens.surface` etc., nu direct din [VColors].
@immutable
class VolteraTokens extends ThemeExtension<VolteraTokens> {
  // Surfaces
  final Color canvas;          // e0
  final Color surface;         // e1
  final Color surfaceRaised;   // e2
  final Color surfaceHover;

  // Borders
  final Color hairline;
  final Color hairlineStrong;

  // Accent
  final Color accent;          // 500
  final Color accentPressed;   // 600
  final Color accentSoft;      // 200 — used on dark text rare
  final Color onAccent;        // text on accent fill

  // Semantic status
  final Color ok;
  final Color warn;
  final Color danger;

  // Text
  final Color textStrong;
  final Color textDefault;
  final Color textMuted;
  final Color textDisabled;

  const VolteraTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.hairline,
    required this.hairlineStrong,
    required this.accent,
    required this.accentPressed,
    required this.accentSoft,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.textStrong,
    required this.textDefault,
    required this.textMuted,
    required this.textDisabled,
  });

  static const VolteraTokens dark = VolteraTokens(
    canvas: VElevation.e0,
    surface: VElevation.e1,
    surfaceRaised: VElevation.e2,
    surfaceHover: VElevation.hover,
    hairline: VColors.hairline,
    hairlineStrong: VColors.hairlineStrong,
    accent: VColors.accent500,
    accentPressed: VColors.accent600,
    accentSoft: VColors.accent200,
    onAccent: VColors.accentOnDark,
    ok: VColors.ok500,
    warn: VColors.warn500,
    danger: VColors.danger500,
    textStrong: VColors.textStrong,
    textDefault: VColors.textDefault,
    textMuted: VColors.textMuted,
    textDisabled: VColors.textDisabled,
  );

  @override
  VolteraTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceHover,
    Color? hairline,
    Color? hairlineStrong,
    Color? accent,
    Color? accentPressed,
    Color? accentSoft,
    Color? onAccent,
    Color? ok,
    Color? warn,
    Color? danger,
    Color? textStrong,
    Color? textDefault,
    Color? textMuted,
    Color? textDisabled,
  }) {
    return VolteraTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      textStrong: textStrong ?? this.textStrong,
      textDefault: textDefault ?? this.textDefault,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
    );
  }

  @override
  VolteraTokens lerp(ThemeExtension<VolteraTokens>? other, double t) {
    if (other is! VolteraTokens) return this;
    return VolteraTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textDefault: Color.lerp(textDefault, other.textDefault, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
    );
  }
}

extension VolteraTokensX on BuildContext {
  VolteraTokens get tokens => Theme.of(this).extension<VolteraTokens>()!;
}
