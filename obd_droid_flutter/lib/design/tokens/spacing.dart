/// Spacing scale, 4px baseline. Folositi DOAR aceste valori.
/// Nu hardcodati 6, 10, 14, 18 — alegeti din scale.
class VSpace {
  VSpace._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s56 = 56;
  static const double s80 = 80;

  // Semantic aliases
  static const double cardPaddingCompact = s16;
  static const double cardPaddingDefault = s20;
  static const double cardPaddingHero = s24;
  static const double cardGap = s12;
  static const double sectionGap = s24;
  static const double screenEdgeMobile = s16;
  static const double screenEdgeTablet = s24;
}
