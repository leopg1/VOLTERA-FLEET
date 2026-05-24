import 'dart:async';
import 'dart:typed_data';

import '../models/connection_state.dart';

/// Low-level byte transport that an ELM327 adapter speaks over.
///
/// Specific implementations (Bluetooth Classic, BLE, USB serial, Wi-Fi, mock)
/// only need to push raw bytes back and forth. The higher-level protocol logic
/// (AT commands, line buffering, response parsing) lives in [ElmEngine].
abstract class ObdTransport {
  /// Description of the underlying adapter (filled in by the discovery step).
  ObdAdapterInfo get adapter;

  /// True once the transport is open and ready to ferry bytes.
  bool get isConnected;

  /// Stream of raw bytes received from the adapter.
  Stream<Uint8List> get incoming;

  /// Open the underlying socket / serial port.
  Future<void> connect();

  /// Send raw bytes (the [ElmEngine] formats AT commands, this is byte-only).
  Future<void> send(Uint8List bytes);

  /// Close the connection and release resources.
  Future<void> disconnect();
}
