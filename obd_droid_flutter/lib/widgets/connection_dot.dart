import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated pulsing dot that signals connection state. Green when live,
/// orange while connecting, red when error/offline.
class ConnectionDot extends StatefulWidget {
  final Color color;
  final bool animate;
  final double size;

  const ConnectionDot({
    super.key,
    this.color = AppColors.green,
    this.animate = true,
    this.size = 10,
  });

  @override
  State<ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<ConnectionDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = widget.animate ? _ctrl.value : 1.0;
        final scale = 1.0 + 0.4 * t;
        return SizedBox(
          width: widget.size * 2.4,
          height: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.20 * (1 - t)),
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.7),
                      blurRadius: 10,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
