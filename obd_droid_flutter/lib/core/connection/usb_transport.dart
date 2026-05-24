import 'dart:async';
import 'dart:typed_data';

import '../models/connection_state.dart';
import 'obd_transport.dart';

/// USB serial transport — placeholder (necesita usb_serial plugin).
/// In versiunea curenta este dezactivat. Foloseste Mock.
class UsbObdTransport implements ObdTransport {
  @override
  final ObdAdapterInfo adapter;

  UsbObdTransport({required this.adapter, required dynamic device});

  @override
  bool get isConnected => false;

  @override
  Stream<Uint8List> get incoming => const Stream.empty();

  @override
  Future<void> connect() => Future.error('USB not enabled in this build.');

  @override
  Future<void> send(Uint8List bytes) => Future.error('USB not enabled.');

  @override
  Future<void> disconnect() async {}
}
