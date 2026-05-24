import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Header de sectiune. Titlu title/18, subtitle optional body/13,
/// trailing optional pentru "VIEW ALL". Subbloc-uri retin focus prin spacing,
/// nu prin border heavy.
class VSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const VSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: VType.title18.copyWith(color: t.textStrong)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: VSpace.s4),
                      Text(
                        subtitle!,
                        style: VType.body13.copyWith(color: t.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: VSpace.s12),
          child,
        ],
      ),
    );
  }
}
