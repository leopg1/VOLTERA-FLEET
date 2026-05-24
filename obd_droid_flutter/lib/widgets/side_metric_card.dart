import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Vertical metric card pentru linia cu masina — icon mic in stanga sus,
/// label uppercase, valoare Orbitron mare, unit Rajdhani in subsol.
class SideMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  final Color statusColor;
  final CrossAxisAlignment align;

  const SideMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.statusColor = AppColors.cyan,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: statusColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: AppText.label(size: 9.5, letterSpacing: 1.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (value == null)
            Shimmer.fromColors(
              baseColor: AppColors.surfaceHi,
              highlightColor: AppColors.border,
              child: Container(
                height: 22,
                width: 70,
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
                    size: 24,
                    color: AppColors.text,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(unit,
                    style: AppText.body(
                        size: 10.5, color: AppColors.textMuted)),
              ],
            ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 28,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                    color: statusColor.withOpacity(0.7), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
