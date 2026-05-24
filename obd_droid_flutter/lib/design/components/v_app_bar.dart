import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// AppBar disciplinat: titlu title/18, subtitle opt body/13 muted,
/// max 2 actions (icon buttons). Background = canvas (e0), zero shadow.
class VAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool centerTitle;

  const VAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppBar(
      backgroundColor: t.canvas,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      titleSpacing: leading == null ? VSpace.s16 : 0,
      title: subtitle == null
          ? Text(title, style: VType.title18.copyWith(color: t.textStrong))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: VType.title18.copyWith(color: t.textStrong)),
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: VType.body13.copyWith(color: t.textMuted)),
              ],
            ),
      actions: [
        ...actions,
        const SizedBox(width: VSpace.s8),
      ],
    );
  }
}
