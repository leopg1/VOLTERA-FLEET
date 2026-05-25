import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/services/cloud_sync.dart';
import '../core/services/location_service.dart';
import '../design/design.dart';

/// Voltera Fleet — Supabase cloud sync configuration.
class FleetConfigScreen extends StatefulWidget {
  const FleetConfigScreen({super.key});

  @override
  State<FleetConfigScreen> createState() => _FleetConfigScreenState();
}

class _FleetConfigScreenState extends State<FleetConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController(
    text: '11111111-1111-1111-1111-111111111111',
  );
  bool _saving = false;
  String? _msg;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_urlCtrl.text.trim().isEmpty ||
        _keyCtrl.text.trim().isEmpty ||
        _vehicleCtrl.text.trim().isEmpty) {
      setState(() => _msg = 'Fill in all fields.');
      return;
    }
    setState(() => _saving = true);
    try {
      await CloudSync.I.configure(
        url: _urlCtrl.text.trim(),
        anonKey: _keyCtrl.text.trim(),
        vehicleId: _vehicleCtrl.text.trim(),
      );
      final granted = await LocationService.I.ensurePermission();
      if (granted) await LocationService.I.start();
      if (!mounted) return;
      setState(() => _msg = granted
          ? 'Cloud active + GPS live. Your pin will appear on the dashboard.'
          : 'Cloud active. GPS denied — samples leave without lat/lon.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleGps() async {
    final gps = LocationService.I;
    if (gps.hasFix && gps.isGranted) {
      await gps.stop();
      if (mounted) setState(() {});
      return;
    }
    final granted = await gps.ensurePermission();
    if (granted) await gps.start();
    if (mounted) setState(() {});
  }

  Future<void> _triggerDemoDtc() async {
    if (!CloudSync.I.isEnabled) {
      setState(() => _msg = 'Save the configuration first.');
      return;
    }
    await CloudSync.I.sendEvent(
      type: 'dtc',
      severity: 'critical',
      code: 'P0420',
      title: 'Catalyst System Efficiency Below Threshold (Bank 1)',
      description: 'Manual trigger from the app for demo.',
      payload: {'demo': true},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.tokens.danger,
        content: const Text('DTC P0420 sent to cloud'),
      ),
    );
  }

  Future<void> _sendTestSample() async {
    if (!CloudSync.I.isEnabled) {
      setState(() => _msg = 'Save the configuration first.');
      return;
    }
    CloudSync.I.enqueueSample(
      lat: 47.6519,
      lon: 26.2553,
      speedKmh: 42,
      rpm: 1850,
      coolant: 88,
      throttle: 28,
      engineLoad: 35,
      maf: 8.4,
      battery: 14.2,
      fuelPct: 67,
      intakeAirTemp: 24,
      mapKpa: 38,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.tokens.ok,
        content: const Text('Test sample queued — flush in 3 s'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = CloudSync.I;
    final gps = context.watch<LocationService>();
    final gpsActive = gps.isGranted && gps.hasFix;
    final t = context.tokens;

    return VScaffold(
      appBar: const VAppBar(title: 'Fleet Cloud'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s40),
        children: [
          // ─── Cloud status
          VCard(
            child: Row(
              children: [
                Icon(
                  sync.isEnabled
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: sync.isEnabled ? t.ok : t.textMuted,
                  size: 28,
                ),
                const SizedBox(width: VSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: sync.isEnabled ? 'Cloud active' : 'Inactive',
                            status: sync.isEnabled
                                ? VStatus.ok
                                : VStatus.neutral,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: VSpace.s4),
                      Text(
                        sync.isEnabled
                            ? 'Vehicle ${sync.vehicleId}\n'
                                'Uploaded ${sync.totalUploaded}  ·  Failed ${sync.failedUploads}'
                            : 'Configure Supabase below.',
                        style: VType.body13.copyWith(color: t.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.cardGap),

          // ─── GPS status
          VCard(
            child: Row(
              children: [
                Icon(
                  gpsActive
                      ? Icons.gps_fixed_rounded
                      : gps.isGranted
                          ? Icons.gps_not_fixed_rounded
                          : Icons.gps_off_rounded,
                  color: gpsActive
                      ? t.ok
                      : gps.isGranted
                          ? t.accent
                          : t.textMuted,
                  size: 28,
                ),
                const SizedBox(width: VSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(
                        label: gpsActive
                            ? 'GPS live'
                            : gps.isGranted
                                ? 'Acquiring'
                                : 'GPS off',
                        status: gpsActive
                            ? VStatus.ok
                            : gps.isGranted
                                ? VStatus.info
                                : VStatus.neutral,
                        dense: true,
                      ),
                      const SizedBox(height: VSpace.s4),
                      Text(
                        gpsActive
                            ? '${gps.lat!.toStringAsFixed(5)}, ${gps.lon!.toStringAsFixed(5)}  ·  ±${gps.accuracyM?.toStringAsFixed(0) ?? "?"} m'
                            : gps.isGranted
                                ? 'Waiting for fix from the tablet GPS…'
                                : 'Enable GPS to broadcast live position.',
                        style: VType.body13.copyWith(color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VSpace.s8),
                IconButton.outlined(
                  tooltip: gpsActive ? 'Stop GPS' : 'Enable GPS',
                  onPressed: _toggleGps,
                  icon: Icon(
                    gpsActive
                        ? Icons.location_disabled_rounded
                        : Icons.my_location_rounded,
                    color: gpsActive ? t.danger : t.accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.sectionGap),

          // ─── Config
          Padding(
            padding: const EdgeInsets.fromLTRB(
                VSpace.s4, 0, VSpace.s4, VSpace.s8),
            child: Text('CONFIGURATION',
                style: VType.label11.copyWith(color: t.textMuted)),
          ),
          _LabeledField(
            label: 'Supabase URL',
            hint: 'https://xxx.supabase.co',
            controller: _urlCtrl,
          ),
          const SizedBox(height: VSpace.s12),
          _LabeledField(
            label: 'Anon key',
            hint: 'eyJhbGciOiJIUzI1NiIs…',
            controller: _keyCtrl,
            obscure: true,
          ),
          const SizedBox(height: VSpace.s12),
          _LabeledField(
            label: 'Vehicle ID (UUID)',
            hint: '11111111-1111-1111-1111-111111111111',
            controller: _vehicleCtrl,
          ),
          const SizedBox(height: VSpace.s16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save & activate'),
          ),
          if (_msg != null) ...[
            const SizedBox(height: VSpace.s12),
            Text(_msg!,
                style: VType.body13.copyWith(color: t.textMuted)),
          ],

          const SizedBox(height: VSpace.sectionGap),

          // ─── Demo triggers
          Padding(
            padding: const EdgeInsets.fromLTRB(
                VSpace.s4, 0, VSpace.s4, VSpace.s8),
            child: Text('DEMO TRIGGERS',
                style: VType.label11.copyWith(color: t.textMuted)),
          ),
          OutlinedButton.icon(
            onPressed: _triggerDemoDtc,
            icon: Icon(Icons.error_outline_rounded, color: t.danger),
            label: const Text('Trigger DTC (P0420)'),
          ),
          const SizedBox(height: VSpace.s12),
          OutlinedButton.icon(
            onPressed: _sendTestSample,
            icon: Icon(Icons.upload_rounded, color: t.accent),
            label: const Text('Send test sample → cloud'),
          ),

          if (sync.lastError != null) ...[
            const SizedBox(height: VSpace.sectionGap),
            Container(
              padding: const EdgeInsets.all(VSpace.s12),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.08),
                borderRadius: VRadius.brSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: t.danger, size: 16),
                  const SizedBox(width: VSpace.s8),
                  Expanded(
                    child: Text('Last error: ${sync.lastError}',
                        style: VType.body13.copyWith(color: t.danger)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
  });
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: VType.label11.copyWith(color: t.textMuted)),
        const SizedBox(height: VSpace.s4),
        TextField(
          controller: controller,
          obscureText: obscure,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          style: VType.mono13.copyWith(color: t.textStrong),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: VType.body13.copyWith(color: t.textDisabled),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
