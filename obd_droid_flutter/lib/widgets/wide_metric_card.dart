import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Card metric "wide" cu progress bar in subsol — pentru Coolant si MAF
/// (cei doi de pe randul mic de sub masina).
class WideMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  final double progress; // 0..1
  final Color statusColor;

  const WideMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    this.statusColor = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.label(size: 9.5, letterSpacing: 1.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (value == null)
                Shimmer.fromColors(
                  baseColor: AppColors.surfaceHi,
                  highlightColor: AppColors.border,
                  child: Container(
                    width: 50, height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value!,
                      style: AppText.digital(
                          size: 18, color: AppColors.text),
                    ),
                    const SizedBox(width: 3),
                    Text(unit,
                        style: AppText.body(
                            size: 10, color: AppColors.textMuted)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  color: AppColors.surfaceHi,
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
