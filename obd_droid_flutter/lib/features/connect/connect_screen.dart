import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import '../../core/models/connection_state.dart';
import '../../design/design.dart';
import '../../providers/connection_provider.dart';

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

  void _openAutoPairSheet() {
    final conn = context.read<ConnectionProvider>();
    conn.startBluetoothDiscovery();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) =>
            _AutoPairSheet(scrollController: scrollController),
      ),
    ).whenComplete(() => conn.stopBluetoothDiscovery());
  }

  Future<void> _saveWifiSettings() async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 35000;
    await context.read<ConnectionProvider>().updateWifiSettings(
          host: _hostCtrl.text.trim(),
          port: port,
        );
    if (!mounted) return;
    await context.read<ConnectionProvider>().startScan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WiFi settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final t = context.tokens;

    final (label, status, pulse) = _statusMap(conn.state);

    return VScaffold(
      appBar: VAppBar(
        title: 'Connect Vehicle',
        actions: [
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: conn.isScanning ? null : () => conn.startScan(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s40),
        children: [
          // Status row
          Row(
            children: [
              Expanded(
                child: ConnectionPill(
                  label: label,
                  meta: conn.activeAdapter?.name,
                  status: status,
                  pulse: pulse,
                ),
              ),
              if (conn.isScanning) ...[
                const SizedBox(width: VSpace.s12),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                ),
              ],
            ],
          ),
          if (conn.lastError != null) ...[
            const SizedBox(height: VSpace.s12),
            _ErrorBanner(message: conn.lastError!),
          ],

          const SizedBox(height: VSpace.s24),

          // ----- WiFi -----
          VSection(
            title: 'WiFi Adapter',
            subtitle:
                'Connect the tablet to the ESP32/ELM327 WiFi network, then '
                'enter its address.',
            child: VCard(
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
                            labelText: 'IP address',
                            hintText: '192.168.0.10',
                            prefixIcon: Icon(Icons.lan_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: VSpace.s12),
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
                  const SizedBox(height: VSpace.s12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveWifiSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: VSpace.s12),
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
          ),

          const SizedBox(height: VSpace.sectionGap),

          // ----- Bluetooth -----
          VSection(
            title: 'Bluetooth Adapter',
            subtitle: 'Auto-pair tries all common PINs; no need to pair '
                'manually in Android settings.',
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openAutoPairSheet,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Auto-pair'),
                  ),
                ),
                const SizedBox(width: VSpace.s12),
                IconButton.outlined(
                  tooltip: 'Android BT settings',
                  onPressed: () async {
                    try {
                      await FlutterBluetoothSerial.instance.openSettings();
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.settings_bluetooth_rounded),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.sectionGap),

          // ----- Adapter list -----
          VSection(
            title: 'Detected adapters',
            subtitle: 'WiFi, paired Bluetooth or Demo. Tap to connect.',
            child: Column(
              children: [
                if (conn.scanResults.isEmpty)
                  EmptyState(
                    icon: Icons.sensors_off_rounded,
                    title: 'No adapters found',
                    body: conn.isScanning
                        ? 'Scanning... give it a few seconds.'
                        : 'Pull to refresh or check the adapter is powered.',
                  )
                else
                  ...conn.scanResults.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: VSpace.s8),
                      child: _AdapterTile(
                        adapter: a,
                        isActive: conn.activeAdapter?.id == a.id,
                        onTap: () => conn.connect(a),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (conn.activeAdapter != null && conn.isReady) ...[
            const SizedBox(height: VSpace.sectionGap),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue to Dashboard'),
            ),
          ],
        ],
      ),
    );
  }

  (String, VStatus, bool) _statusMap(ObdLinkState s) {
    switch (s) {
      case ObdLinkState.disconnected:
        return ('Offline', VStatus.neutral, false);
      case ObdLinkState.scanning:
        return ('Scanning', VStatus.warn, true);
      case ObdLinkState.connecting:
        return ('Linking', VStatus.warn, true);
      case ObdLinkState.initializing:
        return ('Initializing', VStatus.warn, true);
      case ObdLinkState.ready:
        return ('Live', VStatus.ok, true);
      case ObdLinkState.busy:
        return ('Busy', VStatus.info, false);
      case ObdLinkState.error:
        return ('Error', VStatus.danger, false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helpers — preset menu, error banner, adapter tile
// ─────────────────────────────────────────────────────────────────────

class _PresetMenu extends StatelessWidget {
  final void Function(String host, int port) onSelected;
  const _PresetMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<({String host, int port})>(
      tooltip: 'Common WiFi presets',
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: (host: '192.168.0.10', port: 35000),
          child: Text('Clone V-Link  ·  192.168.0.10:35000'),
        ),
        PopupMenuItem(
          value: (host: '192.168.4.1', port: 35000),
          child: Text('ESP32 default  ·  192.168.4.1:35000'),
        ),
        PopupMenuItem(
          value: (host: '192.168.4.1', port: 23),
          child: Text('ESP32 Telnet  ·  192.168.4.1:23'),
        ),
        PopupMenuItem(
          value: (host: '192.168.0.1', port: 35000),
          child: Text('Generic gw  ·  192.168.0.1:35000'),
        ),
      ],
      onSelected: (v) => onSelected(v.host, v.port),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: VSpace.s16),
        decoration: BoxDecoration(
          borderRadius: VRadius.brSm,
          border: Border.all(color: t.hairlineStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 18, color: t.textMuted),
            const SizedBox(width: VSpace.s8),
            Text('Presets',
                style: VType.body15.copyWith(color: t.textStrong)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(VSpace.s16),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.08),
        borderRadius: VRadius.brMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: t.danger, size: 18),
          const SizedBox(width: VSpace.s12),
          Expanded(
            child: Text(message,
                style: VType.body13.copyWith(color: t.danger)),
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
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: VRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: VRadius.brMd,
        child: Container(
          padding: const EdgeInsets.all(VSpace.s16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: VRadius.brMd,
            border: Border.all(
              color: isActive ? t.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: VRadius.brSm,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 20, color: t.textDefault),
              ),
              const SizedBox(width: VSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adapter.name,
                      style: VType.body15.copyWith(
                        color: t.textStrong,
                        fontWeight: FontWeight.w600,
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
                      style: VType.body13.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const StatusBadge(
                  label: 'Active',
                  status: VStatus.ok,
                  icon: Icons.check_rounded,
                  dense: true,
                )
              else
                Icon(Icons.chevron_right_rounded, color: t.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Auto-pair bottom sheet
// ─────────────────────────────────────────────────────────────────────

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
    final ok = await conn.autoPairDevice(
      address,
      customPin: pin.isEmpty ? null : pin,
    );
    if (!mounted) return;
    setState(() {
      _pairing = false;
      _pairingDeviceAddress = null;
    });
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.tokens.ok,
          content: const Text(
            'Adapter paired. Close this panel to continue.',
          ),
        ),
      );
    }
  }

  Future<void> _connectDirect(
    BuildContext context,
    String address,
    String name,
  ) async {
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
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.tokens.ok,
          content: const Text('Connected direct (no PIN). Adapter is live.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.tokens.danger,
          content: Text(
            conn.lastError ??
                'Direct connect failed. Try PAIR (PIN fallback).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final t = context.tokens;
    final results = List.of(conn.discoveryResults)
      ..sort((a, b) {
        final an = (a.device.name ?? '').toUpperCase();
        final bn = (b.device.name ?? '').toUpperCase();
        final ao = an.contains('OBD') || an.contains('ELM');
        final bo = bn.contains('OBD') || bn.contains('ELM');
        if (ao && !bo) return -1;
        if (bo && !ao) return 1;
        return (b.rssi).compareTo(a.rssi);
      });

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        VSpace.s16,
        VSpace.s8,
        VSpace.s16,
        MediaQuery.of(context).viewInsets.bottom + VSpace.s24,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: t.accent, size: 20),
            const SizedBox(width: VSpace.s8),
            const Text('Auto-pair Bluetooth', style: VType.title18),
            const Spacer(),
            if (conn.isDiscovering)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: t.accent),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => conn.startBluetoothDiscovery(),
              ),
          ],
        ),
        const SizedBox(height: VSpace.s4),
        Text(
          'CONNECT = direct, no PIN (Torque Pro / RealDash style, insecure SPP). '
          'PAIR = fallback with common PINs if CONNECT fails.',
          style: VType.body13.copyWith(color: t.textMuted),
        ),
        const SizedBox(height: VSpace.s16),

        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Custom PIN (optional)',
            hintText: 'leave empty for auto-try',
            prefixIcon: Icon(Icons.pin_rounded),
            counterText: '',
          ),
        ),
        const SizedBox(height: VSpace.s12),

        if (conn.autoPairStatus != null)
          Container(
            padding: const EdgeInsets.all(VSpace.s12),
            margin: const EdgeInsets.only(bottom: VSpace.s12),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.08),
              borderRadius: VRadius.brSm,
            ),
            child: Row(
              children: [
                if (_pairing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  )
                else
                  Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
                const SizedBox(width: VSpace.s12),
                Expanded(
                  child: Text(
                    conn.autoPairStatus!,
                    style: VType.body13.copyWith(color: t.textDefault),
                  ),
                ),
              ],
            ),
          ),

        Text('NEARBY DEVICES',
            style: VType.label11.copyWith(color: t.textMuted)),
        const SizedBox(height: VSpace.s8),

        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSpace.s24),
            child: Center(
              child: Text(
                conn.isDiscovering
                    ? 'Scanning... (5-15s)'
                    : 'No devices. Tap refresh.',
                style: VType.body13.copyWith(color: t.textMuted),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: VSpace.s8),
                child: Container(
                  padding: const EdgeInsets.all(VSpace.s12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: VRadius.brSm,
                    border: Border.all(
                      color: isObdLike ? t.accent : t.hairline,
                      width: isObdLike ? 1 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth_rounded,
                        size: 20,
                        color: isObdLike ? t.accent : t.textMuted,
                      ),
                      const SizedBox(width: VSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: VType.body15.copyWith(
                                color: t.textStrong,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$addr  ·  ${r.rssi} dBm'
                              '${r.device.isBonded ? "  ·  paired" : ""}',
                              style: VType.body13.copyWith(color: t.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (isOurTarget && _pairing)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.accent,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              onPressed: _pairing
                                  ? null
                                  : () => _connectDirect(context, addr, name),
                              style: FilledButton.styleFrom(
                                backgroundColor: t.accent,
                                foregroundColor: t.onAccent,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                              child: const Text('Connect'),
                            ),
                            const SizedBox(width: VSpace.s8),
                            OutlinedButton(
                              onPressed: _pairing
                                  ? null
                                  : () => _autoPair(context, addr),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                              child: const Text('Pair'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: VSpace.s8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Close'),
        ),
      ],
    );
  }
}
