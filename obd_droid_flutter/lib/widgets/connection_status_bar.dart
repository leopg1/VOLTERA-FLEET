import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/connection_state.dart';
import '../providers/connection_provider.dart';
import '../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';
import 'connection_dot.dart';

class ConnectionStatusBar extends StatelessWidget {
  final VoidCallback? onTap;
  const ConnectionStatusBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final vehicle = context.watch<VehicleProvider>().vehicle;
    final state = conn.state;
    final (label, color) = _styleFor(state);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ConnectionDot(
                color: color,
                animate: state == ObdLinkState.ready ||
                    state == ObdLinkState.connecting ||
                    state == ObdLinkState.initializing,
              ),
              Text(
                label,
                style: AppText.label(
                  size: 10,
                  color: color,
                  weight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 18, color: AppColors.border),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vehicle?.displayName ??
                          (conn.activeAdapter?.name ?? 'No vehicle'),
                      style: AppText.body(size: 13, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (vehicle?.engine != null)
                      Text(
                        vehicle!.engine!,
                        style: AppText.label(
                          size: 9.5,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SignalBars(
                transport: conn.activeAdapter?.transport,
                active: state == ObdLinkState.ready,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _styleFor(ObdLinkState s) {
    switch (s) {
      case ObdLinkState.disconnected:
        return ('OFFLINE', AppColors.textMuted);
      case ObdLinkState.scanning:
        return ('SCANNING', AppColors.warn);
      case ObdLinkState.connecting:
        return ('LINKING', AppColors.warn);
      case ObdLinkState.initializing:
        return ('INIT', AppColors.warn);
      case ObdLinkState.ready:
        return ('LIVE', AppColors.ok);
      case ObdLinkState.busy:
        return ('BUSY', AppColors.cyan);
      case ObdLinkState.error:
        return ('ERROR', AppColors.danger);
    }
  }
}

class _SignalBars extends StatelessWidget {
  final AdapterTransport? transport;
  final bool active;

  const _SignalBars({required this.transport, required this.active});

  IconData get _icon {
    switch (transport) {
      case AdapterTransport.wifi:
        return Icons.wifi_rounded;
      case AdapterTransport.bluetoothLe:
      case AdapterTransport.bluetoothClassic:
        return Icons.bluetooth_rounded;
      case AdapterTransport.usb:
        return Icons.usb_rounded;
      case AdapterTransport.mock:
        return Icons.science_rounded;
      default:
        return Icons.power_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.cyan : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Container(
              width: 3,
              height: 6.0 + i * 4.0,
              decoration: BoxDecoration(
                color: active
                    ? color
                    : AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Icon(_icon, size: 16, color: color),
      ],
    );
  }
}
