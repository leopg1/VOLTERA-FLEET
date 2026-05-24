import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/diagnostics_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';
import 'fleet_config_screen.dart';
import 'history_screen.dart';
import 'live_sensors_screen.dart';
import 'obd_terminal_screen.dart';
import 'performance_screen.dart';
import 'settings_screen.dart';
import 'track_mode_screen.dart';
import 'vehicle_info_screen.dart';

/// Hub for ancillary features that don't fit in the main bottom nav.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<VehicleProvider>().vehicle;
    final tp = context.watch<TripProvider>();
    final diag = context.watch<DiagnosticsProvider>();
    final conn = context.watch<ConnectionProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.apps_rounded,
                      color: AppColors.cyan, size: 22),
                  const Gap(8),
                  Text('MORE',
                      style: AppText.label(
                          size: 13,
                          color: AppColors.cyan,
                          weight: FontWeight.w900)),
                ],
              ),
              const Gap(16),

              // Hero summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.cyan.withOpacity(0.30)),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.cyan.withOpacity(0.12),
                        blurRadius: 22),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v?.displayName ?? 'Voltera Suite',
                      style: AppText.title(
                          size: 18, weight: FontWeight.w900),
                    ),
                    const Gap(6),
                    Text(
                      v?.vin != null
                          ? 'VIN: ${v!.vin}'
                          : conn.activeAdapter?.name ??
                              'Niciun adaptor activ',
                      style: AppText.body(
                          size: 12, color: AppColors.textMuted),
                    ),
                    const Gap(14),
                    Row(
                      children: [
                        _miniStat('TRASEE', '${tp.saved.length}',
                            AppColors.cyan, Icons.route_rounded),
                        const Gap(8),
                        _miniStat('CODURI', '${diag.all.length}',
                            diag.hasMil ? AppColors.danger : AppColors.ok,
                            Icons.warning_amber_rounded),
                        const Gap(8),
                        _miniStat(
                          'STATUS',
                          conn.activeAdapter != null ? 'LIVE' : 'OFF',
                          conn.activeAdapter != null
                              ? AppColors.ok
                              : AppColors.textMuted,
                          Icons.cable_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const Gap(20),
              Text('FEATURES', style: AppText.label(size: 10)),
              const Gap(10),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _FeatureTile(
                    icon: Icons.flag_rounded,
                    label: 'TRACK MODE',
                    sub: '0-100, lap timer, peak',
                    color: AppColors.orange,
                    onTap: () => _push(context, const TrackModeScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.sensors_rounded,
                    label: 'LIVE SENSORS',
                    sub: 'Toti senzorii cu mini-graphs',
                    color: AppColors.cyan,
                    onTap: () => _push(context, const LiveSensorsScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.directions_car_rounded,
                    label: 'VEHICLE INFO',
                    sub: 'VIN, NHTSA, ECU-uri',
                    color: AppColors.cyan,
                    onTap: () => _push(context, const VehicleInfoScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.timer_rounded,
                    label: 'PERFORMANCE',
                    sub: '0-100, 1/4 mile, frana',
                    color: AppColors.warn,
                    onTap: () => _push(context, const PerformanceScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.terminal_rounded,
                    label: 'OBD TERMINAL',
                    sub: 'Comenzi AT/Mode raw',
                    color: AppColors.cyan,
                    onTap: () => _push(context, const ObdTerminalScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.history_rounded,
                    label: 'HISTORY',
                    sub: 'Sesiuni anterioare',
                    color: AppColors.cyan,
                    onTap: () => _push(context, const HistoryScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.cloud_sync_rounded,
                    label: 'FLEET CLOUD',
                    sub: 'Supabase sync · Voltera Fleet',
                    color: AppColors.ok,
                    onTap: () => _push(context, const FleetConfigScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.settings_rounded,
                    label: 'SETTINGS',
                    sub: 'Conexiune, afisare, AI',
                    color: AppColors.cyan,
                    onTap: () => _push(context, const SettingsScreen()),
                  ),
                  _FeatureTile(
                    icon: Icons.info_rounded,
                    label: 'ABOUT',
                    sub: 'Versiune si echipa',
                    color: AppColors.textMuted,
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),

              const Gap(20),
              Center(
                child: Text(
                  'Voltera · v1.0.0+1 · ICE USV · Offline-first',
                  style: AppText.label(
                      size: 9, color: AppColors.textDim, letterSpacing: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const Gap(4),
            Text(value,
                style: AppText.digital(
                    size: 16, color: color, weight: FontWeight.w900)),
            Text(label,
                style: AppText.label(size: 8.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHi,
        title: Text('Voltera', style: AppText.title()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v1.0.0+1 · ICE USV · 2026',
                style: AppText.digital(
                    size: 14, color: AppColors.cyan)),
            const Gap(10),
            Text(
              'Suita de diagnoza OBD-II + fleet telemetry, construita pentru '
              'tableta auto. Ruleaza offline pe ELM327 WiFi/Bluetooth si urca '
              'date in cloud (Supabase) cand are conexiune.',
              style: AppText.body(size: 13, color: AppColors.textMuted),
            ),
            const Gap(10),
            Text(
              'Build cu Flutter 3 · Provider · Syncfusion · Supabase',
              style:
                  AppText.label(size: 9.5, color: AppColors.textDim),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: AppText.label(
                    color: AppColors.cyan, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: AppText.label(
                          size: 11.5,
                          color: AppColors.text,
                          weight: FontWeight.w900)),
                  const Gap(2),
                  Text(sub,
                      style: AppText.body(
                          size: 11, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
