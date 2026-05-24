import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'status_dot.dart';

/// Pill compact pentru statusul de conexiune in top app bar / hero.
/// Click-able. Heartbeat pulse cand state e activ (ready / connecting).
class ConnectionPill extends StatelessWidget {
  final String label;
  final String? meta; // ex. "WiFi · 5Hz" sau "ELM327 · BT"
  final VStatus status;
  final bool pulse;
  final VoidCallback? onTap;

  const ConnectionPill({
    super.key,
    required this.label,
    this.meta,
    this.status = VStatus.neutral,
    this.pulse = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      borderRadius: VRadius.brSm,
      child: InkWell(
        borderRadius: VRadius.brSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VSpace.s12,
            vertical: VSpace.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(status: status, pulse: pulse),
              const SizedBox(width: VSpace.s12),
              Text(
                label,
                style: VType.body13.copyWith(
                  color: t.textStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(width: VSpace.s8),
                Container(width: 3, height: 3, decoration: BoxDecoration(
                  color: t.textDisabled,
                  shape: BoxShape.circle,
                )),
                const SizedBox(width: VSpace.s8),
                Text(
                  meta!,
                  style: VType.body13.copyWith(color: t.textMuted),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: VSpace.s8),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: t.textDisabled),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
