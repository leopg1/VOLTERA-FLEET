import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../models/connection_state.dart';
import 'obd_transport.dart';

/// Bluetooth Classic (SPP / RFCOMM) transport pentru adaptori ELM327 clasici.
///
/// Acopera 90% din adaptoarele ieftine de pe ebay/aliexpress care expun un
/// serial profile pe MAC-ul dispozitivului. Tipic numele e ceva gen
/// "OBDII", "Vgate iCar", "OBDLink LX", "V-Link", etc.
///
/// Folosim [BluetoothConnection.toAddress] din `flutter_bluetooth_serial`
/// care deschide implicit canalul SPP standard UUID
/// `00001101-0000-1000-8000-00805F9B34FB`.
class BluetoothObdTransport implements ObdTransport {
  @override
  final ObdAdapterInfo adapter;

  final String address;
  final Duration connectTimeout;

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _sub;
  final _incoming = StreamController<Uint8List>.broadcast();
  bool _connected = false;

  BluetoothObdTransport({
    required this.adapter,
    required this.address,
    this.connectTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    // flutter_bluetooth_serial deschide direct canalul SPP standard.
    // Pe Android 12+, pluginul cere intern BLUETOOTH_CONNECT — il acordam
    // din ConnectionProvider inainte sa apelam aici.
    final c = await BluetoothConnection.toAddress(address)
        .timeout(connectTimeout, onTimeout: () {
      throw TimeoutException('Bluetooth: timeout la conectare ($address)');
    });
    _connection = c;

    _sub = c.input?.listen(
      (bytes) {
        if (bytes.isNotEmpty) {
          _incoming.add(Uint8List.fromList(bytes));
        }
      },
      onError: (e) {
        _connected = false;
        if (!_incoming.isClosed) _incoming.addError(e);
      },
      onDone: () {
        _connected = false;
      },
      cancelOnError: false,
    );

    _connected = true;
  }

  @override
  Future<void> send(Uint8List bytes) async {
    final c = _connection;
    if (c == null || !c.isConnected) {
      throw StateError('Bluetooth: not connected.');
    }
    c.output.add(bytes);
    await c.output.allSent;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    if (!_incoming.isClosed) await _incoming.close();
  }
}
