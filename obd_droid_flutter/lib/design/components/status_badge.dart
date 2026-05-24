import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'status_dot.dart';

/// Chip mic semantic: icon optional + text. Folosit pentru severity DTC,
/// state pills compacte (READY, OFFLINE), badge-uri pe liste.
/// Fundalul NU se coloreaza puternic — doar tint 12% sau hairline.
class StatusBadge extends StatelessWidget {
  final String label;
  final VStatus status;
  final IconData? icon;
  final bool tinted;
  final bool dense;

  const StatusBadge({
    super.key,
    required this.label,
    this.status = VStatus.neutral,
    this.icon,
    this.tinted = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = status.resolve(t);
    final bg = tinted
        ? color.withValues(alpha: status == VStatus.neutral ? 0.0 : 0.12)
        : Colors.transparent;
    final border = tinted && status == VStatus.neutral
        ? Border.all(color: t.hairline, width: 1)
        : null;

    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: VSpace.s8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: VSpace.s12, vertical: 6);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: VRadius.brSm,
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: VSpace.s4),
          ],
          Text(
            label.toUpperCase(),
            style: VType.label11.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
