import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Lista item disciplinat. Leading icon optional, title/subtitle, trailing
/// orice (badge, valoare, chevron). Foloseste un singur hairline divider la baza.
class VListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  final bool dense;

  const VListTile({
    super.key,
    this.leadingIcon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.divider = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vPad = dense ? VSpace.s12 : VSpace.s16;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      leadingWidget = SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Icon(leadingIcon, size: 20, color: t.textDefault),
        ),
      );
    }

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: VSpace.s16, vertical: vPad),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: VSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: VType.body15.copyWith(color: t.textStrong),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: VType.body13.copyWith(color: t.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VSpace.s12),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: VSpace.s8),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textDisabled),
          ],
        ],
      ),
    );

    final body = onTap == null
        ? row
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: row),
          );

    if (!divider) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
      ),
      child: body,
    );
  }
}
