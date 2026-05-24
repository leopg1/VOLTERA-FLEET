import 'package:flutter/material.dart';

import 'colors.dart';

/// Trei nivele de suprafata, atat. Diferentierea se face tonal, nu prin shadow.
/// Shadow exista DOAR pentru elemente cu adevarat plutitoare (modal/sheet).
class VElevation {
  VElevation._();

  /// e0 = canvas (scaffold background)
  static const Color e0 = VColors.ink950;

  /// e1 = card resting on canvas
  static const Color e1 = VColors.ink900;

  /// e2 = modal / sheet / focused interactive
  static const Color e2 = VColors.ink800;

  /// hover / pressed background tint
  static const Color hover = VColors.ink700;

  /// Singura umbra permisa — folosita doar pe e2 floating
  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
