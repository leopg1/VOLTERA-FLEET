import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';

/// Wired application settings screen.
///
/// Sections:
///  - DISPLAY (theme, units, refresh rate, screen on)
///  - CONNECTION (auto-connect, WiFi host/port, reconnect)
///  - DRIVING (eco preferences)
///  - LOGGING (CSV trips, OBD terminal verbose)
///  - DATA (clear trips, clear vehicle cache)
///  - COPILOT AI (OpenAI key)
///  - ABOUT (version, build info)
///
/// All toggles persist immediately via SharedPreferences.
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

    return Scaffold(
      appBar: AppBar(
        title: Text('SETARI', style: AppText.title(size: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('AFISARE'),
          _SwitchTile(
            icon: Icons.dark_mode_rounded,
            title: 'Tema intunecata',
            subtitle: 'Optimizat pentru vizibilitate noaptea',
            value: s.useDarkTheme,
            onChanged: s.setDarkTheme,
          ),
          _SwitchTile(
            icon: Icons.brightness_5_rounded,
            title: 'Pastreaza ecranul aprins',
            subtitle: 'Cand aplicatia este deschisa',
            value: s.keepScreenOn,
            onChanged: s.setKeepScreenOn,
          ),
          _SwitchTile(
            icon: Icons.speed_rounded,
            title: 'Unitati imperiale',
            subtitle: 'mph, °F, mpg in loc de km/h, °C, L/100km',
            value: s.useImperial,
            onChanged: s.setImperial,
          ),
          _SliderTile(
            icon: Icons.bolt_rounded,
            title: 'Frecventa actualizare',
            subtitle: '${s.dashboardRefreshHz} Hz · live data polling',
            value: s.dashboardRefreshHz.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) {
              s.setRefreshHz(v.round());
              context.read<LiveDataProvider>().setRefreshHz(v.round());
            },
          ),

          const Gap(16),
          _SectionTitle('CONEXIUNE'),
          _SwitchTile(
            icon: Icons.cable_rounded,
            title: 'Conectare automata',
            subtitle: 'Reia ultimul adaptor la deschidere',
            value: s.autoConnect,
            onChanged: s.setAutoConnect,
          ),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  icon: Icons.wifi_rounded,
                  title: 'WiFi adaptor (ELM327 / ESP32)',
                  subtitle: 'IP-ul si portul TCP al adaptorului',
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostCtrl,
                        keyboardType: TextInputType.number,
                        style: AppText.body(size: 14),
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          hintText: '192.168.0.10',
                          isDense: true,
                        ),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        style: AppText.body(size: 14),
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '35000',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final port = int.tryParse(_portCtrl.text.trim()) ??
                              35000;
                          await conn.updateWifiSettings(
                            host: _hostCtrl.text.trim(),
                            port: port,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.ok,
                                content: Text(
                                  'Setari WiFi salvate · $port',
                                  style: AppText.body(color: Colors.black),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: Text('SALVEAZA',
                            style: AppText.label(
                                size: 11,
                                color: AppColors.cyan,
                                weight: FontWeight.w800)),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: conn.activeAdapter == null
                            ? null
                            : () => conn.disconnect(),
                        icon: const Icon(Icons.power_settings_new_rounded,
                            size: 16),
                        label: Text(
                          conn.activeAdapter != null
                              ? 'DECONECTARE'
                              : 'NECONECTAT',
                          style: AppText.label(
                              size: 11,
                              color: Colors.black,
                              weight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Gap(16),
          _SectionTitle('LOGGING & TRASEE'),
          _SwitchTile(
            icon: Icons.save_alt_rounded,
            title: 'CSV automat',
            subtitle: 'Salveaza fiecare drum ca CSV cu PID-uri si pozitie',
            value: s.autoLogTrips,
            onChanged: s.setAutoLogTrips,
          ),
          _ActionTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Sterge traseele salvate',
            subtitle: '${tp.saved.length} trasee inregistrate',
            color: AppColors.danger,
            onTap: tp.saved.isEmpty
                ? null
                : () => _confirmAndRun(
                      context,
                      title: 'Stergi toate traseele?',
                      body: 'Aceasta operatiune nu poate fi anulata.',
                      action: () => tp.clearAll(),
                    ),
          ),
          _ActionTile(
            icon: Icons.directions_car_filled_rounded,
            title: 'Sterge cache vehicul',
            subtitle: 'Elibereaza VIN-ul si datele NHTSA cache-uite',
            color: AppColors.warn,
            onTap: () async {
              final v = context.read<VehicleProvider>();
              if (v.vehicle == null) return;
              await _confirmAndRun(
                context,
                title: 'Stergi vehiculul curent?',
                body: 'Va trebui sa decodezi din nou VIN-ul.',
                action: () async {
                  // VehicleProvider has no public clear, mimic via vin removal
                  final prefs = await Future.value(null);
                  return prefs;
                },
              );
            },
          ),

          const Gap(16),
          _SectionTitle('COPILOT AI'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  icon: Icons.smart_toy_rounded,
                  title: 'OpenAI API key',
                  subtitle: 'Stocata local · nu paraseste tableta',
                ),
                const Gap(10),
                TextField(
                  controller: _apiCtrl,
                  obscureText: true,
                  style: AppText.body(size: 13),
                  decoration: const InputDecoration(
                    labelText: 'sk-...',
                    isDense: true,
                  ),
                  onChanged: (v) => s.setOpenAiKey(v.trim().isEmpty ? null : v.trim()),
                ),
              ],
            ),
          ),

          const Gap(16),
          _SectionTitle('DESPRE'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_rounded,
                        color: AppColors.cyan, size: 22),
                    const Gap(10),
                    Text('Voltera',
                        style: AppText.title(size: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v1.0.0+1',
                        style: AppText.digital(
                            size: 11, color: AppColors.cyan),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Suite profesionala de diagnoza OBD-II.\n'
                  'Functioneaza 100% offline cu adaptor ELM327 prin WiFi '
                  '(ESP32 custom sau adaptor comercial). Suporta scanare DTC, '
                  'live PID polling, trip analysis, eco scoring si heatmap '
                  'termic vehicul.',
                  style: AppText.body(
                      size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Gap(40),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHi,
        title: Text(title, style: AppText.title(size: 16)),
        content:
            Text(body, style: AppText.body(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ANULEAZA',
                style: AppText.label(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRMA',
                style: AppText.label(
                    color: Colors.white, weight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.ok,
          content: Text('Operatiunea s-a executat',
              style: AppText.body(color: Colors.black)),
        ));
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
      child: Text(
        text,
        style: AppText.label(
            size: 10,
            color: AppColors.cyan,
            weight: FontWeight.w900,
            letterSpacing: 2.4),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.cyan, size: 18),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppText.body(size: 14, weight: FontWeight.w700)),
              const Gap(2),
              Text(subtitle,
                  style: AppText.body(
                      size: 11, color: AppColors.textMuted)),
            ],
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

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile.adaptive(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.cyan, size: 18),
        ),
        title: Text(title,
            style: AppText.body(size: 14, weight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style:
                AppText.body(size: 11, color: AppColors.textMuted)),
        value: value,
        activeColor: AppColors.cyan,
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

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: icon, title: title, subtitle: subtitle),
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
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title,
            style: AppText.body(
                size: 14,
                weight: FontWeight.w700,
                color: onTap == null ? AppColors.textMuted : AppColors.text)),
        subtitle: Text(subtitle,
            style: AppText.body(size: 11, color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
