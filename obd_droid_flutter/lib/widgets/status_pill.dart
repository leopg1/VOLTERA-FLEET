import 'package:flutter/material.dart';

import '../core/models/connection_state.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final ObdLinkState state;
  final ObdAdapterInfo? adapter;
  final VoidCallback? onTap;

  const StatusPill({super.key, required this.state, this.adapter, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _styleFor(state);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.35)),
          color: color.withOpacity(0.10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(color: color, animate: state == ObdLinkState.ready),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0.4,
              ),
            ),
            if (adapter != null) ...[
              const SizedBox(width: 8),
              Text(
                '· ${adapter!.name}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _styleFor(ObdLinkState s) {
    switch (s) {
      case ObdLinkState.disconnected:
        return ('OFFLINE', AppColors.textMuted, Icons.power_off_rounded);
      case ObdLinkState.scanning:
        return ('SCANNING', AppColors.warn, Icons.sensors_rounded);
      case ObdLinkState.connecting:
        return ('CONNECTING', AppColors.warn, Icons.cable_rounded);
      case ObdLinkState.initializing:
        return ('HANDSHAKE', AppColors.warn, Icons.handshake_rounded);
      case ObdLinkState.ready:
        return ('LIVE', AppColors.ok, Icons.bolt_rounded);
      case ObdLinkState.busy:
        return ('BUSY', AppColors.accent, Icons.hourglass_top_rounded);
      case ObdLinkState.error:
        return ('ERROR', AppColors.danger, Icons.error_rounded);
    }
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, this.animate = true});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
        final t = widget.animate ? _ctrl.value : 1;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                  blurRadius: widget.animate ? 8.0 + 6.0 * t : 6.0,
                  spreadRadius: widget.animate ? 1.0 + t : 0.6,
              ),
            ],
          ),
        );
      },
    );
  }
}
