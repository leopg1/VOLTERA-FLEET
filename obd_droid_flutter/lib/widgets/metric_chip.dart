import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Carduri mici orizontale pentru metrici live (temperatura, baterie, MAF...)
/// cu border stang colorat in functie de status.
class MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  final Color accent;
  final double? width;

  const MetricChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.7),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 11),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.label(size: 9.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 3),
              if (value == null)
                Shimmer.fromColors(
                  baseColor: AppColors.surfaceHi,
                  highlightColor: AppColors.border,
                  child: Container(
                    width: 60,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
              else
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: AppText.digital(size: 18, color: AppColors.text),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: AppText.body(
                            size: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
