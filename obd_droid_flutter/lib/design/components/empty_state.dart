import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'status_dot.dart';

/// Empty state restraint. Icon 40dp semantic, titlu, body short, optional CTA.
/// Folosit pe "No active faults", "No trips yet", "Adapter not connected".
class EmptyState extends StatelessWidget {
  final IconData icon;
  final VStatus iconStatus;
  final String title;
  final String? body;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    this.iconStatus = VStatus.neutral,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(VSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.hairline),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 26, color: iconStatus.resolve(t)),
              ),
              const SizedBox(height: VSpace.s16),
              Text(
                title,
                style: VType.title18.copyWith(color: t.textStrong),
                textAlign: TextAlign.center,
              ),
              if (body != null && body!.isNotEmpty) ...[
                const SizedBox(height: VSpace.s8),
                Text(
                  body!,
                  style: VType.body13.copyWith(color: t.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: VSpace.s20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
