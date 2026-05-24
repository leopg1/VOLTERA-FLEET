import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

/// Compact bottom nav. Single accent (cyan): icon + underline gradient
/// + subtle top border. Inactive items in textMuted, no decorative noise.
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == index;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.cyan
                                            .withOpacity(0.45),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              selected ? item.iconActive : item.icon,
                              color: selected
                                  ? AppColors.cyan
                                  : AppColors.textMuted,
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            style: AppText.label(
                              size: 9,
                              color: selected
                                  ? AppColors.cyan
                                  : AppColors.textMuted,
                              weight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 2.4,
                          width: selected ? 28 : 0,
                          decoration: BoxDecoration(
                            gradient: AppColors.cyanGradient,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(2),
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          AppColors.cyan.withOpacity(0.7),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
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
