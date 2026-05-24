import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/connection_state.dart';
import 'obd_transport.dart';

/// TCP socket transport pentru adaptori ELM327 WiFi (inclusiv ESP32).
///
/// Adaptori WiFi tipici (clone V-Link, OBDLink MX+, ESP32 custom) creeaza
/// un AP WiFi (SSID gen "WiFi_OBDII") si expun un TCP server pe portul 35000.
/// Conectezi telefonul/tableta la WiFi-ul lor, apoi vorbesti TCP cu adaptorul.
///
/// Setari implicite:
///   - IP:    192.168.0.10  (standard pentru clone V-Link)
///   - Port:  35000
///
/// Pentru ESP32 cu modul AP propriu:
///   - IP:    192.168.4.1   (default ESP32)
///   - Port:  35000 (sau ce ai setat in firmware)
class WifiObdTransport implements ObdTransport {
  @override
  final ObdAdapterInfo adapter;

  final String host;
  final int port;
  final Duration connectTimeout;

  Socket? _socket;
  StreamSubscription<List<int>>? _sub;
  final _incoming = StreamController<Uint8List>.broadcast();
  bool _connected = false;

  WifiObdTransport({
    required this.adapter,
    required this.host,
    this.port = 35000,
    this.connectTimeout = const Duration(seconds: 8),
  });

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    final socket = await Socket.connect(host, port, timeout: connectTimeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;

    _sub = socket.listen(
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
    final s = _socket;
    if (s == null) throw StateError('TCP socket not connected.');
    s.add(bytes);
    await s.flush();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket?.destroy();
    _socket = null;
    if (!_incoming.isClosed) await _incoming.close();
  }
}
