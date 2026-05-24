import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/vehicle.dart';
import '../design/design.dart';
import '../providers/connection_provider.dart';
import '../providers/vehicle_provider.dart';

/// Vehicle info — VIN + spec table + adapter info.
class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _vinCtrl = TextEditingController();

  @override
  void dispose() {
    _vinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<VehicleProvider>();
    final conn = context.watch<ConnectionProvider>();
    final vehicle = v.vehicle;

    return VScaffold(
      appBar: const VAppBar(title: 'Vehicle Info'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s24),
        children: [
          if (vehicle != null) ...[
            _VehicleHero(vehicle: vehicle),
            const SizedBox(height: VSpace.s16),
          ],

          _VinPanel(
            controller: _vinCtrl,
            conn: conn,
            v: v,
            mounted: () => mounted,
          ),

          if (vehicle != null) ...[
            const SizedBox(height: VSpace.sectionGap),
            _SpecsTable(vehicle: vehicle),
          ],

          if (conn.activeAdapter != null) ...[
            const SizedBox(height: VSpace.sectionGap),
            _AdapterPanel(conn: conn),
          ],

          if (vehicle?.ecuAddresses.isNotEmpty == true) ...[
            const SizedBox(height: VSpace.sectionGap),
            _EcuPanel(vehicle: vehicle!),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────

class _VehicleHero extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleHero({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard.hero(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: VRadius.brSm,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.directions_car_filled_rounded,
                color: t.textDefault, size: 28),
          ),
          const SizedBox(width: VSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.displayName,
                    style: VType.title24.copyWith(color: t.textStrong)),
                if (vehicle.engine != null) ...[
                  const SizedBox(height: 2),
                  Text(vehicle.engine!,
                      style: VType.body13.copyWith(color: t.textMuted)),
                ],
                if (vehicle.vin != null) ...[
                  const SizedBox(height: VSpace.s8),
                  SelectableText(
                    vehicle.vin!,
                    style: VType.mono13.copyWith(color: t.textDefault),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// VIN panel
// ─────────────────────────────────────────────────────────────────────

class _VinPanel extends StatelessWidget {
  final TextEditingController controller;
  final ConnectionProvider conn;
  final VehicleProvider v;
  final bool Function() mounted;
  const _VinPanel({
    required this.controller,
    required this.conn,
    required this.v,
    required this.mounted,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 18, color: t.textDefault),
              const SizedBox(width: VSpace.s8),
              Text('VIN decode',
                  style: VType.title18.copyWith(color: t.textStrong)),
            ],
          ),
          const SizedBox(height: VSpace.s16),
          TextField(
            controller: controller,
            maxLength: 17,
            inputFormatters: [
              UpperCaseTextFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[A-HJ-NPR-Z0-9]')),
            ],
            style: VType.mono15.copyWith(color: t.textStrong),
            decoration: const InputDecoration(
              labelText: 'VIN (17 characters)',
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: VSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cable_rounded, size: 16),
                  onPressed: conn.service == null
                      ? null
                      : () async {
                          await v.readVinFromVehicle(conn.service!);
                          if (mounted()) {
                            controller.text = v.vehicle?.vin ?? '';
                          }
                        },
                  label: const Text('Read from ECU'),
                ),
              ),
              const SizedBox(width: VSpace.s12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.search_rounded, size: 16),
                  onPressed: v.isDecoding
                      ? null
                      : () async {
                          final vin = controller.text.trim();
                          if (vin.length != 17) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: t.warn,
                                content:
                                    const Text('VIN must be 17 characters'),
                              ),
                            );
                            return;
                          }
                          await v.refreshFromVin(vin);
                          if (!context.mounted) return;
                          if (v.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: t.danger,
                                content: Text('NHTSA: ${v.error}'),
                              ),
                            );
                          }
                        },
                  label: Text(v.isDecoding ? 'Decoding…' : 'Decode'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Specs
// ─────────────────────────────────────────────────────────────────────

class _SpecsTable extends StatelessWidget {
  final Vehicle vehicle;
  const _SpecsTable({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entries = <(String, String)>[
      if (vehicle.year != null) ('Year', vehicle.year.toString()),
      if (vehicle.make != null) ('Make', vehicle.make!),
      if (vehicle.model != null) ('Model', vehicle.model!),
      if (vehicle.trim != null) ('Trim', vehicle.trim!),
      if (vehicle.engine != null) ('Engine', vehicle.engine!),
      if (vehicle.fuelType != null) ('Fuel', vehicle.fuelType!),
      if (vehicle.transmission != null) ('Transmission', vehicle.transmission!),
      if (vehicle.bodyClass != null) ('Body class', vehicle.bodyClass!),
      if (vehicle.plant != null) ('Plant', vehicle.plant!),
    ];

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No specs available',
        body: 'Decode a VIN to populate specifications.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VSpace.s4, 0, VSpace.s4, VSpace.s8),
          child: Text('SPECIFICATIONS',
              style: VType.label11.copyWith(color: t.textMuted)),
        ),
        ClipRRect(
          borderRadius: VRadius.brMd,
          child: Container(
            color: t.surface,
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++)
                  ValueRow(
                    label: entries[i].$1,
                    value: entries[i].$2,
                    divider: i < entries.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Adapter panel
// ─────────────────────────────────────────────────────────────────────

class _AdapterPanel extends StatelessWidget {
  final ConnectionProvider conn;
  const _AdapterPanel({required this.conn});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final adapter = conn.activeAdapter!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VSpace.s4, 0, VSpace.s4, VSpace.s8),
          child: Text('ADAPTER',
              style: VType.label11.copyWith(color: t.textMuted)),
        ),
        ClipRRect(
          borderRadius: VRadius.brMd,
          child: Container(
            color: t.surface,
            child: Column(
              children: [
                ValueRow(label: 'Name', value: adapter.name),
                ValueRow(
                  label: 'Transport',
                  value: adapter.transport.name,
                ),
                if (adapter.address != null)
                  ValueRow(label: 'Address', value: adapter.address!),
                if (conn.engine?.firmware != null)
                  ValueRow(label: 'Firmware', value: conn.engine!.firmware!),
                if (conn.engine?.negotiatedProtocol != null)
                  ValueRow(
                    label: 'Protocol',
                    value: conn.engine!.negotiatedProtocol!.label,
                    divider: false,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ECU modules
// ─────────────────────────────────────────────────────────────────────

class _EcuPanel extends StatelessWidget {
  final Vehicle vehicle;
  const _EcuPanel({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_board_rounded,
                  size: 18, color: t.textDefault),
              const SizedBox(width: VSpace.s8),
              Text('ECU modules',
                  style: VType.title18.copyWith(color: t.textStrong)),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          Wrap(
            spacing: VSpace.s8,
            runSpacing: VSpace.s8,
            children: vehicle.ecuAddresses
                .map((a) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: VSpace.s8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.canvas,
                        borderRadius: VRadius.brXs,
                      ),
                      child: Text(a,
                          style:
                              VType.mono13.copyWith(color: t.textDefault)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// VIN uppercase formatter
// ─────────────────────────────────────────────────────────────────────

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
