import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/services/cloud_sync.dart';
import '../core/services/location_service.dart';
import '../theme/app_theme.dart';

/// Voltera Fleet — ecran de configurare cloud sync.
///
/// Pune URL-ul Supabase, anon key-ul si vehicle_id-ul (UUID-ul masinii din
/// tabelul `vehicles`). Dupa save, app-ul incepe sa urce date in cloud
/// automat la urmatorul tick de live polling.
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
      setState(() => _msg = 'Completeaza toate campurile.');
      return;
    }
    setState(() => _saving = true);
    try {
      await CloudSync.I.configure(
        url: _urlCtrl.text.trim(),
        anonKey: _keyCtrl.text.trim(),
        vehicleId: _vehicleCtrl.text.trim(),
      );
      // Pornim GPS-ul automat dupa activarea cloud-ului, ca sample-urile sa
      // primeasca lat/lon si pinul de pe web app sa se miste pe locatia
      // reala a tabletei. Daca utilizatorul refuza permisiunea, sample-urile
      // continua sa plece — doar fara coordonate.
      final granted = await LocationService.I.ensurePermission();
      if (granted) await LocationService.I.start();
      setState(() => _msg = granted
          ? 'Cloud activ + GPS LIVE. Pinul tau apare pe dashboard.'
          : 'Cloud activ. GPS refuzat — sample-urile pleaca fara lat/lon.');
    } catch (e) {
      setState(() => _msg = 'Eroare: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _toggleGps() async {
    final gps = LocationService.I;
    if (gps.hasFix && gps.isGranted) {
      await gps.stop();
      setState(() {});
      return;
    }
    final granted = await gps.ensurePermission();
    if (granted) await gps.start();
    if (mounted) setState(() {});
  }

  Future<void> _triggerDemoDtc() async {
    if (!CloudSync.I.isEnabled) {
      setState(() => _msg = 'Configureaza si salveaza intai.');
      return;
    }
    await CloudSync.I.sendEvent(
      type: 'dtc',
      severity: 'critical',
      code: 'P0420',
      title: 'Catalyst System Efficiency Below Threshold (Bank 1)',
      description: 'Trigger manual din app pentru demo.',
      payload: {'demo': true},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('DTC P0420 trimis catre cloud'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _sendTestSample() async {
    if (!CloudSync.I.isEnabled) {
      setState(() => _msg = 'Configureaza si salveaza intai.');
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
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample de test pus in coada — flush in max 3s'),
        backgroundColor: AppColors.ok,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = CloudSync.I;
    final gps = context.watch<LocationService>();
    final gpsActive = gps.isGranted && gps.hasFix;

    return Scaffold(
      appBar: AppBar(
        title: Text('FLEET CONFIG', style: AppText.title(size: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sync.isEnabled ? AppColors.ok : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sync.isEnabled
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: sync.isEnabled ? AppColors.ok : AppColors.textMuted,
                  size: 32,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sync.isEnabled ? 'CLOUD ACTIV' : 'CLOUD INACTIV',
                        style: AppText.label(
                          size: 12,
                          color: sync.isEnabled
                              ? AppColors.ok
                              : AppColors.textMuted,
                          weight: FontWeight.w900,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        sync.isEnabled
                            ? 'Vehicle: ${sync.vehicleId}\n'
                                'Uploaded: ${sync.totalUploaded} · '
                                'Failed: ${sync.failedUploads}'
                            : 'Configureaza Supabase mai jos.',
                        style: AppText.body(
                          size: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          // GPS card — vizibil, cu buton pentru a porni/opri si coordonatele
          // curente. Asa user-ul stie ca trimite pozitia spre web app.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: gpsActive ? AppColors.ok : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  gpsActive
                      ? Icons.gps_fixed_rounded
                      : gps.isGranted
                          ? Icons.gps_not_fixed_rounded
                          : Icons.gps_off_rounded,
                  color: gpsActive
                      ? AppColors.ok
                      : gps.isGranted
                          ? AppColors.cyan
                          : AppColors.textMuted,
                  size: 28,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gpsActive
                            ? 'GPS LIVE'
                            : gps.isGranted
                                ? 'CAUT SATELITI...'
                                : 'GPS DEZACTIVAT',
                        style: AppText.label(
                          size: 12,
                          color: gpsActive
                              ? AppColors.ok
                              : gps.isGranted
                                  ? AppColors.cyan
                                  : AppColors.textMuted,
                          weight: FontWeight.w900,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        gpsActive
                            ? '${gps.lat!.toStringAsFixed(5)}, ${gps.lon!.toStringAsFixed(5)} '
                                '· ±${gps.accuracyM?.toStringAsFixed(0) ?? "?"}m'
                            : gps.isGranted
                                ? 'Astept fix de la GPS-ul tabletei...'
                                : 'Apasa "ACTIVEAZA GPS" pentru a trimite '
                                    'pozitia live spre web app.',
                        style: AppText.body(
                          size: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                IconButton.outlined(
                  tooltip: gpsActive ? 'Opreste GPS' : 'Activeaza GPS',
                  onPressed: _toggleGps,
                  icon: Icon(
                    gpsActive
                        ? Icons.location_disabled_rounded
                        : Icons.my_location_rounded,
                    color: gpsActive ? AppColors.danger : AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),
          Text('CONFIGURARE',
              style: AppText.label(size: 10, letterSpacing: 1.6)),
          const Gap(10),
          _LabeledField(
            label: 'Supabase URL',
            hint: 'https://xxx.supabase.co',
            controller: _urlCtrl,
          ),
          const Gap(10),
          _LabeledField(
            label: 'Anon Key',
            hint: 'eyJhbGciOiJIUzI1NiIs...',
            controller: _keyCtrl,
            obscure: true,
          ),
          const Gap(10),
          _LabeledField(
            label: 'Vehicle ID (UUID)',
            hint: '11111111-1111-1111-1111-111111111111',
            controller: _vehicleCtrl,
          ),
          const Gap(16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'SALVEAZA & ACTIVEAZA'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_msg != null) ...[
            const Gap(10),
            Text(_msg!,
                style: AppText.body(size: 12, color: AppColors.textMuted)),
          ],
          const Gap(28),
          Text('DEMO TRIGGERS',
              style: AppText.label(size: 10, letterSpacing: 1.6)),
          const Gap(10),
          OutlinedButton.icon(
            onPressed: _triggerDemoDtc,
            icon: const Icon(Icons.error_outline_rounded,
                color: AppColors.danger),
            label: const Text('TRIGGER DTC (P0420)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const Gap(10),
          OutlinedButton.icon(
            onPressed: _sendTestSample,
            icon: const Icon(Icons.upload_rounded, color: AppColors.cyan),
            label: const Text('SAMPLE TEST → CLOUD'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.cyan),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const Gap(28),
          if (sync.lastError != null)
            Text('Ultima eroare: ${sync.lastError}',
                style: AppText.body(size: 11, color: AppColors.danger)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.label(size: 10, color: AppColors.textMuted)),
        const Gap(4),
        TextField(
          controller: controller,
          obscureText: obscure,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          style: AppText.body(size: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppText.body(size: 12, color: AppColors.textDim),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}
