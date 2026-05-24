import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// Cardul de baza din Voltera. Default = surface e1 fara border.
/// Variante: `.hero` (e2 surface, padding mai generos), `.outline` (hairline border).
class VCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VCardVariant variant;
  final VoidCallback? onTap;
  final BorderRadius radius;

  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VSpace.cardPaddingDefault),
    this.variant = VCardVariant.surface,
    this.onTap,
    this.radius = VRadius.brMd,
  });

  const VCard.hero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VSpace.cardPaddingHero),
    this.onTap,
    this.radius = VRadius.brLg,
  }) : variant = VCardVariant.hero;

  const VCard.outline({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VSpace.cardPaddingDefault),
    this.onTap,
    this.radius = VRadius.brMd,
  }) : variant = VCardVariant.outline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Color bg = switch (variant) {
      VCardVariant.surface => t.surface,
      VCardVariant.hero => t.surfaceRaised,
      VCardVariant.outline => t.canvas,
    };
    final BoxBorder? border = variant == VCardVariant.outline
        ? Border.all(color: t.hairline, width: 1)
        : null;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: t.accent.withValues(alpha: 0.08),
        highlightColor: t.accent.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}

enum VCardVariant { surface, hero, outline }
