import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';

/// Patru semantici de status. Atat. Nicio combinatie 'cyan glow' decorativa.
enum VStatus { ok, warn, danger, info, neutral }

extension VStatusColor on VStatus {
  Color resolve(VolteraTokens t) => switch (this) {
        VStatus.ok => t.ok,
        VStatus.warn => t.warn,
        VStatus.danger => t.danger,
        VStatus.info => t.accent,
        VStatus.neutral => t.textMuted,
      };
}

/// Dot 8dp semantic. Heartbeat optional pentru "live" (connected, recording).
class StatusDot extends StatefulWidget {
  final VStatus status;
  final double size;
  final bool pulse;

  const StatusDot({
    super.key,
    required this.status,
    this.size = 8,
    this.pulse = false,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _c.repeat();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.status.resolve(context.tokens);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
    if (!widget.pulse) return dot;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Halou subtil: opacity 0.4 → 0, scale 1.0 → 2.2
        return SizedBox(
          width: widget.size * 2.4,
          height: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (0.4 * (1 - t)).clamp(0.0, 0.4),
                child: Container(
                  width: widget.size * (1.0 + 1.2 * t),
                  height: widget.size * (1.0 + 1.2 * t),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: dot,
    );
  }
}
