import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/connection_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';

/// Settings — sectiuni grupate cu hairline divider intern.
/// Toggle-uri Material native (Switch theme). Niciun card colorat heavy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    final c = context.read<ConnectionProvider>();
    _apiCtrl.text = s.openAiApiKey ?? '';
    _hostCtrl.text = c.wifiHost;
    _portCtrl.text = c.wifiPort.toString();
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final conn = context.watch<ConnectionProvider>();
    final tp = context.watch<TripProvider>();
    final t = context.tokens;

    return VScaffold(
      appBar: const VAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s40),
        children: [
          // ─── Display
          _Group(title: 'Display', children: [
            _SwitchTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark theme',
              subtitle: 'Optimized for night visibility',
              value: s.useDarkTheme,
              onChanged: s.setDarkTheme,
            ),
            _SwitchTile(
              icon: Icons.brightness_5_rounded,
              title: 'Keep screen on',
              subtitle: 'While the app is open',
              value: s.keepScreenOn,
              onChanged: s.setKeepScreenOn,
            ),
            _SwitchTile(
              icon: Icons.speed_rounded,
              title: 'Imperial units',
              subtitle: 'mph, °F, mpg instead of km/h, °C, L/100',
              value: s.useImperial,
              onChanged: s.setImperial,
            ),
            _SliderTile(
              icon: Icons.bolt_rounded,
              title: 'Refresh rate',
              subtitle: '${s.dashboardRefreshHz} Hz · live data polling',
              value: s.dashboardRefreshHz.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) {
                s.setRefreshHz(v.round());
                context.read<LiveDataProvider>().setRefreshHz(v.round());
              },
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.s16),

          // ─── Connection
          _Group(title: 'Connection', children: [
            _SwitchTile(
              icon: Icons.cable_rounded,
              title: 'Auto-connect',
              subtitle: 'Resume last adapter on app open',
              value: s.autoConnect,
              onChanged: s.setAutoConnect,
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.s12),

          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 18, color: t.textDefault),
                    const SizedBox(width: VSpace.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WiFi adapter',
                              style: VType.body15.copyWith(
                                  color: t.textStrong,
                                  fontWeight: FontWeight.w600)),
                          Text('TCP host + port',
                              style: VType.body13
                                  .copyWith(color: t.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.s16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostCtrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          hintText: '192.168.0.10',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.s12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '35000',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final port =
                              int.tryParse(_portCtrl.text.trim()) ?? 35000;
                          await conn.updateWifiSettings(
                            host: _hostCtrl.text.trim(),
                            port: port,
                          );
                          if (!mounted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: t.ok,
                              content: Text('WiFi settings saved · :$port'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: VSpace.s12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: conn.activeAdapter == null
                            ? null
                            : () => conn.disconnect(),
                        icon: const Icon(Icons.power_settings_new_rounded,
                            size: 16),
                        label: Text(
                          conn.activeAdapter != null
                              ? 'Disconnect'
                              : 'Not connected',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.s16),

          // ─── Logging & trips
          _Group(title: 'Logging & trips', children: [
            _SwitchTile(
              icon: Icons.save_alt_rounded,
              title: 'Automatic CSV',
              subtitle: 'Save every trip as CSV (PIDs + GPS)',
              value: s.autoLogTrips,
              onChanged: s.setAutoLogTrips,
            ),
            _ActionTile(
              icon: Icons.delete_sweep_rounded,
              title: 'Clear saved trips',
              subtitle: '${tp.saved.length} trips recorded',
              status: VStatus.danger,
              onTap: tp.saved.isEmpty
                  ? null
                  : () => _confirmAndRun(
                        context,
                        title: 'Delete all trips?',
                        body: 'This action cannot be undone.',
                        action: () => tp.clearAll(),
                      ),
            ),
            _ActionTile(
              icon: Icons.directions_car_filled_rounded,
              title: 'Clear vehicle cache',
              subtitle: 'Release the cached VIN + NHTSA data',
              status: VStatus.warn,
              onTap: () async {
                final v = context.read<VehicleProvider>();
                if (v.vehicle == null) return;
                await _confirmAndRun(
                  context,
                  title: 'Clear current vehicle?',
                  body: 'You will need to decode the VIN again.',
                  action: () async {},
                );
              },
              divider: false,
            ),
          ]),

          const SizedBox(height: VSpace.s16),

          // ─── Copilot AI
          _Group(title: 'Copilot AI', children: [
            VListTile(
              leadingIcon: Icons.smart_toy_rounded,
              title: 'OpenAI API key',
              subtitle: 'Stored locally, never leaves the tablet',
              divider: false,
              trailing: SizedBox(
                width: 180,
                child: TextField(
                  controller: _apiCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'sk-…',
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      s.setOpenAiKey(v.trim().isEmpty ? null : v.trim()),
                ),
              ),
            ),
          ]),

          const SizedBox(height: VSpace.s16),

          // ─── About
          _Group(title: 'About', children: [
            VListTile(
              leadingIcon: Icons.info_outline_rounded,
              title: 'Voltera',
              subtitle: 'OBD-II diagnostics + fleet telemetry',
              trailing: Text('v1.0.0+1',
                  style: VType.mono13.copyWith(color: t.textMuted)),
              divider: false,
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String body,
    required Future Function() action,
  }) async {
    final t = context.tokens;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action();
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: t.ok,
          content: const Text('Done'),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings primitives
// ─────────────────────────────────────────────────────────────────────

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

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final bool divider;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return VListTile(
      leadingIcon: icon,
      title: title,
      subtitle: subtitle,
      divider: divider,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final IconData icon;
  final ValueChanged<double> onChanged;
  final bool divider;

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.icon,
    required this.onChanged,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: VSpace.s16, vertical: VSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: t.textDefault),
              const SizedBox(width: VSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: VType.body15.copyWith(
                            color: t.textStrong,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: VType.body13.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
              Text(value.round().toString(),
                  style: VType.mono15.copyWith(color: t.accent)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ],
      ),
    );

    if (!divider) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
      ),
      child: row,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VStatus status;
  final VoidCallback? onTap;
  final bool divider;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = onTap == null ? t.textDisabled : status.resolve(t);
    return VListTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Center(child: Icon(icon, color: color, size: 20)),
      ),
      title: title,
      subtitle: subtitle,
      divider: divider,
      onTap: onTap,
    );
  }
}
