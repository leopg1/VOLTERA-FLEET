import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/models/vehicle.dart';
import '../providers/connection_provider.dart';
import '../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';

/// Detailed vehicle information page — displays VIN, NHTSA-decoded fields
/// and adapter info. Allows manual VIN decode + read VIN from car.
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

    return Scaffold(
      appBar:
          AppBar(title: Text('VEHICLE INFO', style: AppText.title(size: 16))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vehicle != null) _vehicleHero(vehicle),

              const Gap(14),
              _vinPanel(context, conn, v),
              const Gap(14),

              if (vehicle != null) ...[
                Text('SPECIFICATII', style: AppText.label(size: 10)),
                const Gap(8),
                _specGrid(vehicle),
                const Gap(14),
              ],
              if (conn.activeAdapter != null) _adapterPanel(conn),
              if (vehicle?.ecuAddresses.isNotEmpty == true) ...[
                const Gap(14),
                _ecuPanel(vehicle!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleHero(Vehicle v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.cyan.withOpacity(0.12), blurRadius: 22),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.cyan,
              size: 32,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.displayName,
                    style:
                        AppText.title(size: 18, weight: FontWeight.w900)),
                if (v.engine != null) ...[
                  const Gap(2),
                  Text(v.engine!,
                      style: AppText.body(
                          size: 12, color: AppColors.textMuted)),
                ],
                const Gap(6),
                if (v.vin != null)
                  SelectableText(
                    v.vin!,
                    style: AppText.digital(size: 12, color: AppColors.cyan),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vinPanel(
      BuildContext context, ConnectionProvider conn, VehicleProvider v) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: AppColors.cyan, size: 18),
              const Gap(8),
              Text('VIN DECODE',
                  style: AppText.label(size: 11, color: AppColors.cyan)),
            ],
          ),
          const Gap(8),
          TextField(
            controller: _vinCtrl,
            maxLength: 17,
            inputFormatters: [
              UpperCaseTextFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[A-HJ-NPR-Z0-9]')),
            ],
            style: AppText.digital(size: 14, color: AppColors.cyan),
            decoration: const InputDecoration(
              labelText: 'VIN (17 caractere)',
              counterText: '',
              isDense: true,
            ),
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cable_rounded, size: 16),
                  onPressed: conn.service == null
                      ? null
                      : () async {
                          await v.readVinFromVehicle(conn.service!);
                          if (mounted) {
                            _vinCtrl.text = v.vehicle?.vin ?? '';
                          }
                        },
                  label: Text('CITESTE DIN ECU',
                      style: AppText.label(
                          size: 11,
                          color: AppColors.cyan,
                          weight: FontWeight.w800)),
                ),
              ),
              const Gap(8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.search_rounded,
                      size: 16, color: Colors.black),
                  onPressed: v.isDecoding
                      ? null
                      : () async {
                          final vin = _vinCtrl.text.trim();
                          if (vin.length != 17) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.warn,
                                content: Text(
                                  'VIN-ul trebuie sa aiba 17 caractere',
                                  style: AppText.body(color: Colors.black),
                                ),
                              ),
                            );
                            return;
                          }
                          await v.refreshFromVin(vin);
                          if (mounted && v.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.danger,
                                content: Text('NHTSA: ${v.error}',
                                    style:
                                        AppText.body(color: Colors.white)),
                              ),
                            );
                          }
                        },
                  label: Text(
                    v.isDecoding ? 'DECODE...' : 'DECODE',
                    style: AppText.label(
                        size: 11,
                        color: Colors.black,
                        weight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specGrid(Vehicle v) {
    final entries = <_KV>[
      if (v.year != null) _KV('AN', v.year.toString()),
      if (v.make != null) _KV('MARCA', v.make!),
      if (v.model != null) _KV('MODEL', v.model!),
      if (v.trim != null) _KV('TRIM', v.trim!),
      if (v.engine != null) _KV('MOTOR', v.engine!),
      if (v.fuelType != null) _KV('CARBURANT', v.fuelType!),
      if (v.transmission != null) _KV('TRANSM', v.transmission!),
      if (v.bodyClass != null) _KV('CAROSERIE', v.bodyClass!),
      if (v.plant != null) _KV('UZINA', v.plant!),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.4,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.k, style: AppText.label(size: 9)),
              const Gap(2),
              Text(e.v,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 12, weight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  Widget _adapterPanel(ConnectionProvider conn) {
    final adapter = conn.activeAdapter!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cable_rounded,
                  color: AppColors.cyan, size: 18),
              const Gap(8),
              Text('ADAPTOR',
                  style: AppText.label(size: 11, color: AppColors.cyan)),
            ],
          ),
          const Gap(10),
          _kv('Nume', adapter.name),
          _kv('Transport', adapter.transport.name.toUpperCase()),
          if (adapter.address != null) _kv('Adresa', adapter.address!),
          if (conn.engine?.firmware != null)
            _kv('Firmware', conn.engine!.firmware!),
          if (conn.engine?.negotiatedProtocol != null)
            _kv('Protocol', conn.engine!.negotiatedProtocol!.label),
        ],
      ),
    );
  }

  Widget _ecuPanel(Vehicle v) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_board_rounded,
                  color: AppColors.cyan, size: 18),
              const Gap(8),
              Text('MODULE ECU',
                  style: AppText.label(size: 11, color: AppColors.cyan)),
            ],
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: v.ecuAddresses
                .map((a) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLo,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(a,
                          style: AppText.digital(
                              size: 11, color: AppColors.cyan)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(k, style: AppText.label(size: 10))),
          Expanded(
            child: Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 12)),
          ),
        ],
      ),
    );
  }
}

class _KV {
  final String k;
  final String v;
  const _KV(this.k, this.v);
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
