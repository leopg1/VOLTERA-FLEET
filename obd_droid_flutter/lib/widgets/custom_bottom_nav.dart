import 'package:flutter/material.dart';

import '../design/design.dart';

class NavItem {
  final IconData icon;
  final IconData iconActive;
  final String label;
  const NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
  });
}

/// Bottom nav disciplinat. Accent doar pe item-ul activ — fara glow shadow,
/// fara gradient indicator. Hairline divider sus, surface tonal.
class CustomBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<NavItem> items;

  const CustomBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.hairline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == index;
              final item = items[i];
              final color = selected ? t.accent : t.textMuted;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    splashColor: t.accent.withValues(alpha: 0.08),
                    highlightColor: t.accent.withValues(alpha: 0.04),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                selected ? item.iconActive : item.icon,
                                key: ValueKey('${item.label}-$selected'),
                                color: color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: VSpace.s4),
                            Text(
                              item.label,
                              style: VType.body13.copyWith(
                                color: color,
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Indicator subtle, 2dp, no shadow
                        Positioned(
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: 2,
                            width: selected ? 24 : 0,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
