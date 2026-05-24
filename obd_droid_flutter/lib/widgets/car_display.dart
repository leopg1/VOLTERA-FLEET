import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Top-view masina, colorata cyan, cu glow neon subtil. Folosita ca element
/// vizual central in dashboard.
class CarDisplay extends StatefulWidget {
  /// Optional active wheel highlights (FL, FR, RL, RR).
  final bool engineRunning;

  const CarDisplay({super.key, this.engineRunning = false});

  @override
  State<CarDisplay> createState() => _CarDisplayState();
}

class _CarDisplayState extends State<CarDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) {
        final glow = 0.5 + 0.5 * _glowCtrl.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                AppColors.cyan.withOpacity(0.10 * glow),
                AppColors.cyan.withOpacity(0.0),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo behind car
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withOpacity(0.25 * glow),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Car SVG tinted cyan
              Center(
                child: SvgPicture.asset(
                  'assets/images/car_top.svg',
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    AppColors.cyan,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
