import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Rand "label — value" pentru info dense (tabele live sensors, specs vehicul).
/// Value-ul foloseste mono ca sa fie aliniat coloanar pe rand-uri adiacente.
class ValueRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool divider;

  const ValueRow({
    super.key,
    required this.label,
    this.value,
    this.unit,
    this.leadingIcon,
    this.onTap,
    this.trailing,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasValue = value != null && value!.isNotEmpty;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VSpace.s16,
        vertical: VSpace.s12,
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18, color: t.textMuted),
            const SizedBox(width: VSpace.s12),
          ],
          Expanded(
            child: Text(
              label,
              style: VType.body15.copyWith(color: t.textDefault),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hasValue ? value! : '—',
                  style: VType.mono15.copyWith(
                    color: hasValue ? t.textStrong : t.textDisabled,
                  ),
                ),
                if (unit != null && unit!.isNotEmpty) ...[
                  const SizedBox(width: VSpace.s4),
                  Text(
                    unit!,
                    style: VType.body13.copyWith(color: t.textMuted),
                  ),
                ],
              ],
            ),
        ],
      ),
    );

    final body = onTap == null
        ? row
        : InkWell(onTap: onTap, child: row);

    if (!divider) return body;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
      ),
      child: body,
    );
  }
}
