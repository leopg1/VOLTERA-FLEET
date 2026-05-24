import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/connection/bluetooth_transport.dart';
import '../core/connection/mock_transport.dart';
import '../core/connection/obd_transport.dart';
import '../core/connection/wifi_transport.dart';
import '../core/models/connection_state.dart';
import '../core/obd/elm_engine.dart';
import '../core/obd/obd_service.dart';

/// Top-level state for the OBD connection lifecycle.
///
/// Suporta:
///  - WiFi (TCP) — pentru adaptori ELM327 WiFi (inclusiv ESP32 custom)
///  - Mock — pentru testare fara adaptor fizic
class ConnectionProvider extends ChangeNotifier {
  ElmEngine? _engine;
  ObdService? _service;
  ObdAdapterInfo? _activeAdapter;
  ObdLinkState _state = ObdLinkState.disconnected;
  String? _lastError;

  // WiFi defaults — utilizatorul le poate schimba din UI
  String wifiHost = '192.168.0.10';
  int wifiPort = 35000;

  ObdService? get service => _service;
  ElmEngine? get engine => _engine;
  ObdAdapterInfo? get activeAdapter => _activeAdapter;
  ObdLinkState get state => _state;
  String? get lastError => _lastError;
  bool get isReady =>
      _state == ObdLinkState.ready || _state == ObdLinkState.busy;

  ConnectionProvider() {
    _restoreWifiSettings();
  }

  Future<void> _restoreWifiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    wifiHost = prefs.getString('wifiHost') ?? '192.168.0.10';
    wifiPort = prefs.getInt('wifiPort') ?? 35000;
    notifyListeners();
  }

  Future<void> updateWifiSettings({String? host, int? port}) async {
    if (host != null && host.trim().isNotEmpty) wifiHost = host.trim();
    if (port != null && port > 0) wifiPort = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifiHost', wifiHost);
    await prefs.setInt('wifiPort', wifiPort);
    notifyListeners();
  }

  // ---------- Lista adaptori disponibili ----------

  final List<ObdAdapterInfo> _scanResults = [];
  List<ObdAdapterInfo> get scanResults => List.unmodifiable(_scanResults);

  bool _scanning = false;
  bool get isScanning => _scanning;

  Future<void> startScan() async {
    _scanning = true;
    _scanResults.clear();
    notifyListeners();

    // 1. WiFi adapter — la adresa configurata
    _scanResults.add(ObdAdapterInfo(
      id: 'wifi:$wifiHost:$wifiPort',
      name: 'ELM327 WiFi (ESP32)',
      transport: AdapterTransport.wifi,
      address: '$wifiHost:$wifiPort',
    ));

    // 2. Bluetooth Classic paired devices (filtrate dupa nume ELM/OBD)
    try {
      final granted = await _ensureBluetoothPermissions();
      if (granted) {
        final state = await FlutterBluetoothSerial.instance.state;
        if (state != BluetoothState.STATE_OFF) {
          final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
          for (final d in bonded) {
            final name = d.name ?? d.address;
            // Adaugam toate device-urile asociate, dar marcam vizual cele
            // care par sa fie ELM327. Daca utilizatorul are si casti BT
            // legate, le vede dar nu va incerca sa se conecteze la ele.
            final looksObd = _looksLikeObd(name);
            _scanResults.add(ObdAdapterInfo(
              id: 'bt:${d.address}',
              name: looksObd ? '$name  ⛽' : name,
              transport: AdapterTransport.bluetoothClassic,
              address: d.address,
              metadata: {'bonded': true, 'isObd': looksObd},
            ));
          }
        } else {
          _lastError = 'Bluetooth oprit. Activeaza-l din setarile tabletei.';
        }
      } else {
        _lastError = 'Permisiuni Bluetooth refuzate. '
            'Acorda-le din Setari → Aplicatii → Voltera.';
      }
    } catch (e) {
      // Nu intrerupem scan-ul daca BT pica — WiFi + Demo raman disponibile.
      if (kDebugMode) print('[scan] BT scan failed: $e');
    }

    // 3. Adaptor demo
    _scanResults.add(const ObdAdapterInfo(
      id: 'mock',
      name: 'Demo Vehicle (fara adaptor fizic)',
      transport: AdapterTransport.mock,
    ));

    _scanning = false;
    notifyListeners();
  }

  /// Cere permisiunile Bluetooth necesare pe Android 12+
  /// (BLUETOOTH_SCAN, BLUETOOTH_CONNECT) si Location (necesara pe Android 6-11
  /// pentru BT scan). Pe Android < 12, permisiunile noi sunt no-ops la runtime
  /// deci consideram OK daca nu sunt explicit "permanentlyDenied".
  Future<bool> _ensureBluetoothPermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final connect = results[Permission.bluetoothConnect];
    // Acceptam granted (Android 12+), limited (rar) si denied implicit
    // care apare pe Android < 12 unde permisiunea nu exista nativ.
    if (connect == null) return true;
    if (connect.isPermanentlyDenied) return false;
    return true;
  }

  bool _looksLikeObd(String name) {
    final n = name.toUpperCase();
    return n.contains('OBD') ||
        n.contains('ELM') ||
        n.contains('VGATE') ||
        n.contains('VLINK') ||
        n.contains('V-LINK') ||
        n.contains('OBDLINK') ||
        n.contains('CARLY') ||
        n.contains('TORQUE') ||
        n.contains('ICAR');
  }

  // ============================================================
  // BLUETOOTH DISCOVERY & AUTO-PAIRING
  // ============================================================
  //
  // Permite utilizatorului sa descopere adaptori Bluetooth in jur si sa-i
  // asocieze automat, incercand pe rand PIN-urile uzuale (1234, 0000, 6789,
  // etc.). Util cand sistemul Android refuza PIN-ul "normal" din setari —
  // foarte des intamplator la clone ELM327 ieftine pe Android 13+.

  final List<BluetoothDiscoveryResult> _discoveryResults = [];
  List<BluetoothDiscoveryResult> get discoveryResults =>
      List.unmodifiable(_discoveryResults);
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySub;
  bool _discovering = false;
  bool get isDiscovering => _discovering;

  /// PIN-urile de incercat la auto-pair, in ordinea probabilitatii.
  static const _autoPairPins = [
    '1234', '0000', '6789', '1111', '8888', '2222', '4321', '5555', '0123',
  ];

  String? _autoPairStatus;
  String? get autoPairStatus => _autoPairStatus;

  Future<void> startBluetoothDiscovery() async {
    if (_discovering) return;
    _discoveryResults.clear();
    _autoPairStatus = null;
    notifyListeners();

    final granted = await _ensureBluetoothPermissions();
    if (!granted) {
      _autoPairStatus = 'Permisiuni Bluetooth refuzate.';
      notifyListeners();
      return;
    }

    try {
      // Asiguram ca BT e pornit
      final state = await FlutterBluetoothSerial.instance.state;
      if (state == BluetoothState.STATE_OFF) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
    } catch (_) {}

    _discovering = true;
    notifyListeners();

    try {
      _discoverySub = FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((r) {
        // dedupe pe adresa
        final idx = _discoveryResults.indexWhere(
          (e) => e.device.address == r.device.address,
        );
        if (idx >= 0) {
          _discoveryResults[idx] = r;
        } else {
          _discoveryResults.add(r);
        }
        notifyListeners();
      }, onDone: () {
        _discovering = false;
        notifyListeners();
      }, onError: (e) {
        _discovering = false;
        _autoPairStatus = 'Eroare scan: $e';
        notifyListeners();
      });
    } catch (e) {
      _discovering = false;
      _autoPairStatus = 'Nu pot porni discovery: $e';
      notifyListeners();
    }
  }

  Future<void> stopBluetoothDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
    _discovering = false;
    notifyListeners();
  }

  /// Conexiune directa **fara bonding** — adauga device-ul descoperit ca
  /// adaptor in scanResults si initiaza conectarea imediat. Foloseste
  /// `createInsecureRfcommSocketToServiceRecord` patch-uit in plugin, exact
  /// ca Torque Pro & RealDash. Pe majoritatea clonelor ELM327 ieftine, asta
  /// merge instant chiar daca pairing-ul standard cu PIN esueaza.
  Future<bool> connectWithoutPairing(String address, String name) async {
    final adapter = ObdAdapterInfo(
      id: 'bt:$address',
      name: name.contains('OBD') || name.toUpperCase().contains('ELM')
          ? '$name  ⛽'
          : name,
      transport: AdapterTransport.bluetoothClassic,
      address: address,
      metadata: {'insecure': true, 'bonded': false},
    );
    // Asiguram ca apare in lista principala
    final exists = _scanResults.any((a) => a.id == adapter.id);
    if (!exists) {
      _scanResults.add(adapter);
    }
    _autoPairStatus = 'Conectare directa la $name...';
    notifyListeners();

    await connect(adapter);
    return _state == ObdLinkState.ready || _state == ObdLinkState.busy;
  }

  /// Incearca pe rand toate PIN-urile uzuale pentru asocierea unui adaptor.
  /// Returneaza true daca s-a asociat cu succes.
  Future<bool> autoPairDevice(String address, {String? customPin}) async {
    final pins = customPin != null && customPin.isNotEmpty
        ? [customPin, ..._autoPairPins.where((p) => p != customPin)]
        : List<String>.from(_autoPairPins);

    // Daca e deja asociat, scoatem si reincercam (uneori bonded dar broken)
    try {
      final bonded =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      if (bonded.any((d) => d.address == address)) {
        _autoPairStatus = 'Deja asociat. Verific conexiunea...';
        notifyListeners();
        // Daca e deja asociat, considera success — nu trebuie alt PIN.
        await startScan();
        return true;
      }
    } catch (_) {}

    for (final pin in pins) {
      if (!_discovering && _discoverySub == null) {
        // Continuam doar daca user-ul nu a abandonat
      }
      _autoPairStatus = 'Incerc PIN $pin...';
      notifyListeners();

      // Inregistreaza handler pt PIN auto-furnizat
      FlutterBluetoothSerial.instance.setPairingRequestHandler((request) async {
        // Tip Pin: ne cere doar codul numeric
        return pin;
      });

      try {
        final ok = await FlutterBluetoothSerial.instance
            .bondDeviceAtAddress(address, pin: pin)
            .timeout(const Duration(seconds: 15));
        if (ok == true) {
          _autoPairStatus = 'Asociat cu PIN $pin ✓';
          FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
          notifyListeners();
          await startScan();
          return true;
        }
      } catch (e) {
        if (kDebugMode) print('[autoPair] PIN $pin failed: $e');
      }

      // Cleanup intre incercari
      try {
        await FlutterBluetoothSerial.instance.removeDeviceBondWithAddress(address);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 600));
    }

    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _autoPairStatus = 'Niciun PIN nu a functionat. Incearca PIN custom.';
    notifyListeners();
    return false;
  }

  // ---------- Connect / disconnect ----------

  Future<void> connect(ObdAdapterInfo adapter) async {
    await disconnect();

    ObdTransport transport;
    switch (adapter.transport) {
      case AdapterTransport.mock:
        transport = MockObdTransport();
        break;
      case AdapterTransport.wifi:
        transport = WifiObdTransport(
          adapter: adapter,
          host: wifiHost,
          port: wifiPort,
        );
        break;
      case AdapterTransport.bluetoothClassic:
        if (adapter.address == null || adapter.address!.isEmpty) {
          _lastError = 'Adaptor Bluetooth fara MAC. Asociaza-l intai din '
              'Setari → Bluetooth, apoi reia scan-ul.';
          _state = ObdLinkState.error;
          notifyListeners();
          return;
        }
        transport = BluetoothObdTransport(
          adapter: adapter,
          address: adapter.address!,
        );
        break;
      case AdapterTransport.bluetoothLe:
      case AdapterTransport.usb:
        _lastError = 'Acest tip de adaptor nu este activ momentan. '
            'Foloseste WiFi, Bluetooth Classic sau Demo.';
        _state = ObdLinkState.error;
        notifyListeners();
        return;
    }

    final engine = ElmEngine(transport);

    _state = ObdLinkState.connecting;
    _activeAdapter = adapter;
    _lastError = null;
    notifyListeners();

    engine.stateStream.listen((s) {
      _state = s;
      notifyListeners();
    });

    try {
      await engine.open();
      _engine = engine;
      _service = ObdService(engine);
      _state = ObdLinkState.ready;
    } catch (e) {
      _lastError = 'Conectare esuata: $e\n\nVerifica:\n'
          '• Esti conectat la WiFi-ul ESP32?\n'
          '• IP corect ($wifiHost) si port ($wifiPort)?\n'
          '• Adaptorul e alimentat (12V de la OBD)?';
      _state = ObdLinkState.error;
      try {
        await engine.close();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    final e = _engine;
    _engine = null;
    _service = null;
    _activeAdapter = null;
    _state = ObdLinkState.disconnected;
    notifyListeners();
    if (e != null) {
      try {
        await e.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
