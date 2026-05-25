import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/models/pid.dart';
import '../core/obd/obd_service.dart';
import '../core/obd/pid_catalog.dart';
import '../core/services/cloud_sync.dart';
import '../core/services/location_service.dart';

/// Polls a chosen list of PIDs at a configurable rate and exposes the latest
/// snapshot to the UI.
class LiveDataProvider extends ChangeNotifier {
  final List<Pid> _pids = List.of(PidCatalog.dashboardDefaults);
  final Map<int, PidSample> _latest = {};
  final Map<int, Queue<PidSample>> _history = {};
  Timer? _ticker;
  ObdService? _service;
  int _refreshHz = 5;
  bool _polling = false;

  // Statistici pentru debug
  int totalReads = 0;
  int failedReads = 0;
  String? lastError;
  DateTime? lastSuccessAt;

  List<Pid> get pids => List.unmodifiable(_pids);
  Map<int, PidSample> get latest => UnmodifiableMapView(_latest);
  bool get isPolling => _polling;
  int get refreshHz => _refreshHz;

  /// Bind to a service and auto-start polling.
  void bind(ObdService? service) {
    if (identical(_service, service)) return;
    _service = service;
    if (service != null) {
      start();
    } else {
      stop();
    }
  }

  void setRefreshHz(int hz) {
    _refreshHz = hz.clamp(1, 20);
    if (_polling) {
      stop();
      start();
    }
  }

  void setPids(List<Pid> pids) {
    _pids
      ..clear()
      ..addAll(pids);
    _latest.clear();
    _history.clear();
    notifyListeners();
  }

  void start() {
    if (_service == null || _polling) return;
    _polling = true;
    _scheduleNext();
    notifyListeners();
  }

  void stop() {
    _polling = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  Queue<PidSample> historyFor(Pid p) =>
      _history.putIfAbsent(p.code, () => Queue<PidSample>());

  void _scheduleNext() {
    if (!_polling) return;
    final period = Duration(milliseconds: (1000 / _refreshHz).round());
    _ticker = Timer(period, _tick);
  }

  Future<void> _tick() async {
    if (!_polling) return;
    final svc = _service;
    if (svc == null) {
      _scheduleNext();
      return;
    }
    for (final pid in _pids) {
      if (!_polling) break;
      try {
        final sample = await svc.readPid(pid);
        totalReads++;
        if (sample == null) {
          failedReads++;
          continue;
        }
        lastSuccessAt = DateTime.now();
        _latest[pid.code] = sample;
        final h = historyFor(pid);
        h.add(sample);
        while (h.length > 240) {
          h.removeFirst();
        }
      } catch (e) {
        failedReads++;
        lastError = e.toString();
      }
    }
    // Push catre cloud (Voltera Fleet) — no-op daca CloudSync nu e configurat.
    // Lat/lon vin din LocationService daca utilizatorul a acordat GPS.
    if (_polling && CloudSync.I.isEnabled) {
      final gps = LocationService.I;
      CloudSync.I.enqueueSample(
        lat: gps.hasFix ? gps.lat : null,
        lon: gps.hasFix ? gps.lon : null,
        speedKmh: _latest[0x0D]?.value,
        rpm: _latest[0x0C]?.value,
        coolant: _latest[0x05]?.value,
        throttle: _latest[0x11]?.value,
        engineLoad: _latest[0x04]?.value,
        maf: _latest[0x10]?.value,
        battery: _latest[0x42]?.value,
        fuelPct: _latest[0x2F]?.value,
        intakeAirTemp: _latest[0x0F]?.value,
        mapKpa: _latest[0x0B]?.value,
      );
    }

    if (_polling) notifyListeners();
    _scheduleNext();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
