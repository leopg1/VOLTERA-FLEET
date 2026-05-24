import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import '../../core/models/connection_state.dart';
import '../../providers/connection_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_pill.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = context.read<ConnectionProvider>();
    _hostCtrl.text = c.wifiHost;
    _portCtrl.text = c.wifiPort.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProvider>().startScan();
    });
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _openAutoPairSheet(BuildContext context) {
    final conn = context.read<ConnectionProvider>();
    conn.startBluetoothDiscovery();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _AutoPairSheet(scrollController: scrollController),
        ),
      ),
    ).whenComplete(() => conn.stopBluetoothDiscovery());
  }

  Future<void> _saveWifiSettings() async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 35000;
    await context.read<ConnectionProvider>().updateWifiSettings(
          host: _hostCtrl.text.trim(),
          port: port,
        );
    if (mounted) {
      await context.read<ConnectionProvider>().startScan();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setari WiFi salvate')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptor OBD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: conn.isScanning ? null : () => conn.startScan(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                StatusPill(state: conn.state, adapter: conn.activeAdapter),
                const Spacer(),
                if (conn.isScanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (conn.lastError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: conn.lastError!),
            ],
            const SizedBox(height: 18),

            // ----- WiFi settings -----
            _SectionHeader(
              icon: Icons.wifi_rounded,
              title: 'Adaptor WiFi (ESP32 / ELM327 wireless)',
              subtitle:
                  'Conecteaza tableta la WiFi-ul adaptorului, apoi introdu '
                  'adresa lui IP si portul.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostCtrl,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'IP adresa',
                            hintText: '192.168.0.10',
                            prefixIcon: Icon(Icons.lan_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '35000',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveWifiSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Salveaza'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PresetMenu(
                          onSelected: (host, port) {
                            _hostCtrl.text = host;
                            _portCtrl.text = port.toString();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            _SectionHeader(
              icon: Icons.bluetooth_rounded,
              title: 'Adaptor Bluetooth (ELM327 clasic)',
              subtitle: 'Auto-pair incearca toate PIN-urile uzuale, nu mai '
                  'trebuie sa-l asociezi manual din setarile Android.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openAutoPairSheet(context),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Auto-pair adaptor'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Setari Bluetooth Android',
                  onPressed: () async {
                    try {
                      await FlutterBluetoothSerial.instance.openSettings();
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.settings_bluetooth_rounded),
                ),
              ],
            ),

            const SizedBox(height: 22),
            _SectionHeader(
              icon: Icons.usb_rounded,
              title: 'Adaptori detectati',
              subtitle: 'WiFi, Bluetooth Classic asociat sau Demo. '
                  'Selecteaza unul ca sa pornesti conectarea.',
            ),
            const SizedBox(height: 10),
            ...conn.scanResults.map(
              (a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _AdapterTile(
                  adapter: a,
                  isActive: conn.activeAdapter?.id == a.id,
                  onTap: () => conn.connect(a),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (conn.activeAdapter != null && conn.isReady)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.dashboard_rounded),
                label: const Text('Continua catre Dashboard'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetMenu extends StatelessWidget {
  final void Function(String host, int port) onSelected;
  const _PresetMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<({String host, int port})>(
      tooltip: 'Presetari WiFi populare',
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: (host: '192.168.0.10', port: 35000),
          child: Text('Clone V-Link (192.168.0.10:35000)'),
        ),
        PopupMenuItem(
          value: (host: '192.168.4.1', port: 35000),
          child: Text('ESP32 default AP (192.168.4.1:35000)'),
        ),
        PopupMenuItem(
          value: (host: '192.168.4.1', port: 23),
          child: Text('ESP32 Telnet (192.168.4.1:23)'),
        ),
        PopupMenuItem(
          value: (host: '192.168.0.1', port: 35000),
          child: Text('Generic gateway (192.168.0.1:35000)'),
        ),
      ],
      onSelected: (v) => onSelected(v.host, v.port),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.tune_rounded, size: 18, color: AppColors.textMuted),
            SizedBox(width: 8),
            Text('Presetari'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12.5, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _AdapterTile extends StatelessWidget {
  final ObdAdapterInfo adapter;
  final bool isActive;
  final VoidCallback onTap;

  const _AdapterTile({
    required this.adapter,
    required this.isActive,
    required this.onTap,
  });

  IconData get _icon {
    switch (adapter.transport) {
      case AdapterTransport.bluetoothLe:
      case AdapterTransport.bluetoothClassic:
        return Icons.bluetooth_rounded;
      case AdapterTransport.usb:
        return Icons.usb_rounded;
      case AdapterTransport.wifi:
        return Icons.wifi_rounded;
      case AdapterTransport.mock:
        return Icons.science_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.stroke,
              width: isActive ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adapter.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        adapter.transportLabel,
                        if (adapter.address != null) adapter.address!,
                      ].join('  ·  '),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet care porneste discovery + auto-pair pe adaptorul ales.
class _AutoPairSheet extends StatefulWidget {
  final ScrollController scrollController;
  const _AutoPairSheet({required this.scrollController});

  @override
  State<_AutoPairSheet> createState() => _AutoPairSheetState();
}

class _AutoPairSheetState extends State<_AutoPairSheet> {
  final _pinCtrl = TextEditingController();
  bool _pairing = false;
  String? _pairingDeviceAddress;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoPair(BuildContext context, String address) async {
    setState(() {
      _pairing = true;
      _pairingDeviceAddress = address;
    });
    final conn = context.read<ConnectionProvider>();
    final pin = _pinCtrl.text.trim();
    final ok = await conn.autoPairDevice(address, customPin: pin.isEmpty ? null : pin);
    if (!mounted) return;
    setState(() {
      _pairing = false;
      _pairingDeviceAddress = null;
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.ok,
          content: Text('Adaptor asociat. Inchide acest panou pentru a continua.'),
        ),
      );
    }
  }

  /// Conectare directa fara pairing — exact ca Torque Pro / RealDash.
  Future<void> _connectDirect(
      BuildContext context, String address, String name) async {
    setState(() {
      _pairing = true;
      _pairingDeviceAddress = address;
    });
    final conn = context.read<ConnectionProvider>();
    await conn.stopBluetoothDiscovery();
    final ok = await conn.connectWithoutPairing(address, name);
    if (!mounted) return;
    setState(() {
      _pairing = false;
      _pairingDeviceAddress = null;
    });
    if (ok) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.ok,
          content: Text('Conectat direct (fara PIN). Adaptorul e live.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(conn.lastError ?? 'Conectare directa esuata. '
              'Incearca PAIR (fallback cu PIN).'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final results = List.of(conn.discoveryResults)
      ..sort((a, b) {
        // ELM-like primii
        final an = (a.device.name ?? '').toUpperCase();
        final bn = (b.device.name ?? '').toUpperCase();
        final ao = an.contains('OBD') || an.contains('ELM');
        final bo = bn.contains('OBD') || bn.contains('ELM');
        if (ao && !bo) return -1;
        if (bo && !ao) return 1;
        return (b.rssi).compareTo(a.rssi);
      });

    return Container(
      color: AppColors.surface,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.auto_fix_high_rounded, color: AppColors.cyan),
                const SizedBox(width: 8),
                const Text('Auto-pair adaptor Bluetooth',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (conn.isDiscovering)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => conn.startBluetoothDiscovery(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'CONNECT = direct, fara PIN (ca Torque Pro / RealDash — insecure SPP). '
              'PAIR = fallback cu PIN-uri uzuale daca CONNECT esueaza.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),

            // PIN custom optional
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN custom (optional)',
                hintText: 'lasa gol pentru auto-try',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),

            // Status
            if (conn.autoPairStatus != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    if (_pairing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.cyan, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(conn.autoPairStatus!,
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),

            const Text('DEVICE-URI APROAPE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    conn.isDiscovering
                        ? 'Scanez... (asteapta 5-15s)'
                        : 'Niciun device. Apasa refresh.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                itemBuilder: (_, i) {
                        final r = results[i];
                        final name = r.device.name ?? r.device.address;
                        final addr = r.device.address;
                        final isOurTarget = _pairingDeviceAddress == addr;
                        final isObdLike = name.toUpperCase().contains('OBD') ||
                            name.toUpperCase().contains('ELM');
                        return Card(
                          color: AppColors.surfaceHi,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isObdLike
                                  ? AppColors.cyan.withValues(alpha: 0.4)
                                  : AppColors.border,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth_rounded,
                              color:
                                  isObdLike ? AppColors.cyan : AppColors.textMuted,
                            ),
                            title: Text(
                              isObdLike ? '$name  ⛽' : name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '$addr · RSSI ${r.rssi} dBm'
                              '${r.device.isBonded ? "  ·  ASOCIAT" : ""}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textMuted),
                            ),
                            trailing: isOurTarget && _pairing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Conectare DIRECTA (fara PIN) — ca Torque Pro
                                      FilledButton(
                                        onPressed: _pairing
                                            ? null
                                            : () => _connectDirect(
                                                context, addr, name),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.ok,
                                          foregroundColor: AppColors.bg,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('CONNECT'),
                                      ),
                                      const SizedBox(width: 6),
                                      // Fallback: pair cu PIN daca CONNECT esueaza
                                      OutlinedButton(
                                        onPressed: _pairing
                                            ? null
                                            : () => _autoPair(context, addr),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.cyan,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                        ),
                                        child: const Text('PAIR'),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Inchide'),
            ),
          ],
        ),
    );
  }
}
