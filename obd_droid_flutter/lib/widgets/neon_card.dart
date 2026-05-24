import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard surface card. Single accent only (cyan). Border subtle 1px.
class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color glow;
  final bool showGlow;
  final BorderRadiusGeometry? radius;

  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.glow = AppColors.cyan,
    this.showGlow = false,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? BorderRadius.circular(14);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: r,
        border: Border.all(
          color: showGlow ? glow.withOpacity(0.30) : AppColors.border,
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glow.withOpacity(0.12),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
