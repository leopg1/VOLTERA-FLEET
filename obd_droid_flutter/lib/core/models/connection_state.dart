enum ObdLinkState {
  disconnected,
  scanning,
  connecting,
  initializing,
  ready,
  busy,
  error,
}

enum AdapterTransport { bluetoothClassic, bluetoothLe, usb, wifi, mock }

class ObdAdapterInfo {
  final String id;
  final String name;
  final AdapterTransport transport;
  final String? address;
  final int? rssi;
  final Map<String, dynamic> metadata;

  const ObdAdapterInfo({
    required this.id,
    required this.name,
    required this.transport,
    this.address,
    this.rssi,
    this.metadata = const {},
  });

  String get transportLabel {
    switch (transport) {
      case AdapterTransport.bluetoothClassic:
        return 'Bluetooth';
      case AdapterTransport.bluetoothLe:
        return 'BLE';
      case AdapterTransport.usb:
        return 'USB';
      case AdapterTransport.wifi:
        return 'Wi-Fi';
      case AdapterTransport.mock:
        return 'Demo';
    }
  }
}
