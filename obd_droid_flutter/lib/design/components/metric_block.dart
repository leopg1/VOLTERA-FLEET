import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'status_dot.dart';

/// Singura componenta care randeaza un numar mare. label/11 mic, valoare mare,
/// unitate disereta. Are 3 size-uri si optional o iconita+status la dreapta.
class MetricBlock extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final MetricSize size;
  final VStatus? status; // dot disereta la dreapta label-ului
  final IconData? leadingIcon;
  final CrossAxisAlignment crossAxis;
  final String? hint; // body13 sub valoare (ex. "+2.4 km vs avg")

  const MetricBlock({
    super.key,
    required this.label,
    this.value,
    this.unit,
    this.size = MetricSize.md,
    this.status,
    this.leadingIcon,
    this.crossAxis = CrossAxisAlignment.start,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final valueStyle = switch (size) {
      MetricSize.hero => VType.display72.copyWith(color: t.textStrong),
      MetricSize.lg => VType.display40.copyWith(color: t.textStrong),
      MetricSize.md => VType.title24.copyWith(
          color: t.textStrong,
          fontFamily: VType.mono,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      MetricSize.sm => VType.mono15.copyWith(color: t.textStrong),
    };
    final unitStyle = (size == MetricSize.hero || size == MetricSize.lg)
        ? VType.body15.copyWith(color: t.textMuted)
        : VType.body13.copyWith(color: t.textMuted);

    final hasValue = value != null && value!.isNotEmpty;
    final displayValue = hasValue ? value! : '—';

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row: icon · LABEL · status dot
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 16, color: t.textMuted),
              const SizedBox(width: VSpace.s8),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: VType.label11.copyWith(color: t.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: VSpace.s8),
              StatusDot(status: status!),
            ],
          ],
        ),
        const SizedBox(height: VSpace.s8),
        // Value · unit baseline-aligned
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                displayValue,
                style: valueStyle.copyWith(
                  color: hasValue ? t.textStrong : t.textDisabled,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null && unit!.isNotEmpty) ...[
              const SizedBox(width: VSpace.s4),
              Text(
                unit!,
                style: unitStyle,
              ),
            ],
          ],
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: VSpace.s4),
          Text(hint!, style: VType.body13.copyWith(color: t.textMuted)),
        ],
      ],
    );
  }
}

enum MetricSize { sm, md, lg, hero }
