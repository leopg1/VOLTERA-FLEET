import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../models/connection_state.dart';
import 'obd_transport.dart';

/// A simulated ELM327 transport used when no physical adapter is available.
///
/// It speaks just enough of the protocol to make every screen come alive with
/// believable values — perfect for design reviews, demos, and emulator testing.
class MockObdTransport implements ObdTransport {
  @override
  final ObdAdapterInfo adapter = const ObdAdapterInfo(
    id: 'mock',
    name: 'Demo Vehicle',
    transport: AdapterTransport.mock,
  );

  final _outgoing = StreamController<Uint8List>.broadcast();
  bool _connected = false;
  final _rng = Random();

  // Simulated vehicle state.
  double _rpmTarget = 850;
  double _rpm = 850;
  double _speed = 0;
  double _coolant = 78;
  Timer? _drift;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get incoming => _outgoing.stream;

  @override
  Future<void> connect() async {
    _connected = true;
    _drift = Timer.periodic(const Duration(milliseconds: 250), (_) => _wander());
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _drift?.cancel();
    await _outgoing.close();
  }

  @override
  Future<void> send(Uint8List bytes) async {
    final cmd = String.fromCharCodes(bytes).trim().toUpperCase();
    final response = _respond(cmd);
    _outgoing.add(Uint8List.fromList(utf8Bytes('$response\r>')));
  }

  void _wander() {
    if (_rng.nextDouble() < 0.05) {
      _rpmTarget = 800 + _rng.nextDouble() * 4500;
    }
    _rpm += (_rpmTarget - _rpm) * 0.15;
    _speed = ((_rpm - 800) / 60).clamp(0, 220);
    _coolant = 78 + sin(DateTime.now().millisecondsSinceEpoch / 4000) * 6;
  }

  String _respond(String cmd) {
    if (cmd.startsWith('AT')) return 'OK';
    if (cmd == '0100') return '41 00 BE 3F A8 13';
    if (cmd == '0120') return '41 20 90 07 B0 11';
    if (cmd == '0140') return '41 40 7A 1C 80 00';

    if (cmd == '010C') {
      final raw = (_rpm * 4).round();
      final hi = (raw >> 8) & 0xFF;
      final lo = raw & 0xFF;
      return '41 0C ${_h(hi)} ${_h(lo)}';
    }
    if (cmd == '010D') return '41 0D ${_h(_speed.round())}';
    if (cmd == '0105') return '41 05 ${_h(_coolant.round() + 40)}';
    if (cmd == '0111') return '41 11 ${_h((40 + _rng.nextInt(80)).clamp(0, 255))}';
    if (cmd == '0104') return '41 04 ${_h((50 + _rng.nextInt(120)).clamp(0, 255))}';
    if (cmd == '010F') return '41 0F ${_h(75)}';
    if (cmd == '0110') return '41 10 ${_h(0)} ${_h(_rng.nextInt(180))}';
    if (cmd == '0142') return '41 42 ${_h(56)} ${_h(72)}';
    if (cmd == '012F') return '41 2F ${_h(180)}';

    if (cmd == '0902') {
      // VIN response (multi-frame). Demo VIN: 1HGCM82633A004352
      return '49 02 01 00 00 00 31\r\n49 02 02 48 47 43 4D\r\n49 02 03 38 32 36 33\r\n49 02 04 33 41 30 30\r\n49 02 05 34 33 35 32';
    }
    if (cmd == '03') {
      // Demo: 3 stored DTCs — P0301 (misfire #1), P0420 (cat eff B1), P0171 (lean B1)
      return '43 03 03 01 04 20 01 71';
    }
    if (cmd == '07') {
      // Demo: 1 pending — P0455 (large EVAP leak)
      return '47 01 04 55';
    }
    if (cmd == '0A') return 'NO DATA';
    return 'NO DATA';
  }

  String _h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();

  static List<int> utf8Bytes(String s) => s.codeUnits;
}
