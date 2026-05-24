import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/connection_provider.dart';
import '../providers/diagnostics_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import 'fleet_config_screen.dart';
import 'history_screen.dart';
import 'live_sensors_screen.dart';
import 'obd_terminal_screen.dart';
import 'performance_screen.dart';
import 'settings_screen.dart';
import 'track_mode_screen.dart';
import 'vehicle_info_screen.dart';

/// Hub-ul featurilor secundare. Lista disciplinata, fara grid colorat.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<VehicleProvider>().vehicle;
    final tp = context.watch<TripProvider>();
    final diag = context.watch<DiagnosticsProvider>();
    final conn = context.watch<ConnectionProvider>();
    final t = context.tokens;

    return VScaffold(
      appBar: const VAppBar(
        title: 'More',
        subtitle: 'Tools, history & configuration',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s24),
        children: [
          // ─── Vehicle hero card
          VCard.hero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v?.displayName ?? 'Voltera Suite',
                  style: VType.title24.copyWith(color: t.textStrong),
                ),
                const SizedBox(height: VSpace.s4),
                Text(
                  v?.vin != null
                      ? 'VIN ${v!.vin}'
                      : conn.activeAdapter?.name ?? 'No active adapter',
                  style: VType.body13.copyWith(color: t.textMuted),
                ),
                const SizedBox(height: VSpace.s20),
                Row(
                  children: [
                    Expanded(
                      child: MetricBlock(
                        label: 'Trips',
                        value: tp.saved.length.toString(),
                        size: MetricSize.md,
                      ),
                    ),
                    Container(width: 1, height: 32, color: t.hairline),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: VSpace.s16),
                        child: MetricBlock(
                          label: 'Codes',
                          value: diag.all.length.toString(),
                          size: MetricSize.md,
                          status: diag.hasMil ? VStatus.danger : VStatus.ok,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 32, color: t.hairline),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: VSpace.s16),
                        child: MetricBlock(
                          label: 'Link',
                          value: conn.activeAdapter != null
                              ? 'Live'
                              : 'Off',
                          size: MetricSize.sm,
                          status: conn.activeAdapter != null
                              ? VStatus.ok
                              : VStatus.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.sectionGap),

          // ─── Tools & diagnostics
          _Group(title: 'Tools & diagnostics', children: [
            VListTile(
              leadingIcon: Icons.sensors_rounded,
              title: 'Live Sensors',
              subtitle: 'All PIDs, mini graphs',
              onTap: () => _push(context, const LiveSensorsScreen()),
            ),
            VListTile(
              leadingIcon: Icons.terminal_rounded,
              title: 'OBD Terminal',
              subtitle: 'AT / Mode raw commands',
              onTap: () => _push(context, const ObdTerminalScreen()),
            ),
            VListTile(
              leadingIcon: Icons.directions_car_rounded,
              title: 'Vehicle Info',
              subtitle: 'VIN, NHTSA, ECUs',
              onTap: () => _push(context, const VehicleInfoScreen()),
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.s16),

          // ─── Driving
          _Group(title: 'Driving', children: [
            VListTile(
              leadingIcon: Icons.flag_rounded,
              title: 'Track Mode',
              subtitle: 'Lap timer, peak hold',
              onTap: () => _push(context, const TrackModeScreen()),
            ),
            VListTile(
              leadingIcon: Icons.timer_rounded,
              title: 'Performance',
              subtitle: '0–100, quarter mile, braking',
              onTap: () => _push(context, const PerformanceScreen()),
            ),
            VListTile(
              leadingIcon: Icons.history_rounded,
              title: 'Trip History',
              subtitle: 'Previous sessions',
              onTap: () => _push(context, const HistoryScreen()),
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.s16),

          // ─── System
          _Group(title: 'System', children: [
            VListTile(
              leadingIcon: Icons.cloud_sync_rounded,
              title: 'Fleet Cloud',
              subtitle: 'Supabase sync · Voltera Fleet',
              onTap: () => _push(context, const FleetConfigScreen()),
            ),
            VListTile(
              leadingIcon: Icons.tune_rounded,
              title: 'Settings',
              subtitle: 'Connection, display, AI',
              onTap: () => _push(context, const SettingsScreen()),
            ),
            VListTile(
              leadingIcon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'Version, team',
              onTap: () => _showAbout(context),
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.sectionGap),
          Center(
            child: Text(
              'Voltera · v1.0.0+1 · ICE USV',
              style: VType.body13.copyWith(color: t.textDisabled),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showAbout(BuildContext context) {
    final t = context.tokens;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Voltera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v1.0.0+1 · ICE USV · 2026',
                style: VType.mono15.copyWith(color: t.accent)),
            const SizedBox(height: VSpace.s12),
            Text(
              'OBD-II diagnostics and fleet telemetry suite, built for '
              'in-vehicle tablets. Runs offline on ELM327 WiFi/Bluetooth '
              'and uploads to the cloud (Supabase) when connected.',
              style: VType.body13.copyWith(color: t.textMuted),
            ),
            const SizedBox(height: VSpace.s12),
            Text(
              'Flutter 3 · Provider · Syncfusion · Supabase',
              style: VType.body13.copyWith(color: t.textDisabled),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VSpace.s4, 0, VSpace.s4, VSpace.s8),
          child: Text(
            title.toUpperCase(),
            style: VType.label11.copyWith(color: t.textMuted),
          ),
        ),
        ClipRRect(
          borderRadius: VRadius.brMd,
          child: Container(
            color: t.surface,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
