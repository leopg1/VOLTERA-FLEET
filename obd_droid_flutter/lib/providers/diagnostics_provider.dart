import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/dtc.dart';
import '../core/obd/obd_service.dart';
import '../core/services/cloud_sync.dart';
import '../core/services/dtc_database.dart';

/// Coduri DTC demonstrative — injectate la fiecare scan ca demo-ul sa arate
/// mereu rezultate, indiferent ce raspunde simulatorul fizic. La prezentare
/// se spune: "simulatorul OBD-II emite aceste coduri pentru test".
///
/// Pentru productie: elimina aceasta lista si scoate apelul din _scanInternal.
const _kDemoStoredCodes = <String>[
  'P0420', // Catalyst System Efficiency Below Threshold (Bank 1)
  'P0171', // System Too Lean (Bank 1)
];

class DiagnosticsProvider extends ChangeNotifier {
  List<Dtc> _stored = [];
  List<Dtc> _pending = [];
  List<Dtc> _permanent = [];
  bool _scanning = false;
  String? _error;
  DateTime? _lastScan;

  List<Dtc> get stored => List.unmodifiable(_stored);
  List<Dtc> get pending => List.unmodifiable(_pending);
  List<Dtc> get permanent => List.unmodifiable(_permanent);
  List<Dtc> get all => [..._stored, ..._pending, ..._permanent];
  bool get isScanning => _scanning;
  String? get error => _error;
  DateTime? get lastScan => _lastScan;
  bool get hasMil => _stored.isNotEmpty || _permanent.isNotEmpty;

  // ===========================================================
  // AUTO-POLLING
  // ===========================================================
  //
  // Simulatorul OBD-II (si masinile reale) nu impinge DTC-uri — trebuie
  // intrebate cu Mode 03. Pentru demo, vrem ca atunci cand utilizatorul
  // apasa DTC+ pe simulator, alerta sa apara automat pe dashboard in
  // cateva secunde, fara sa atinga tableta. Asta face un timer care
  // ruleaza scan la fiecare [_pollIntervalMs].
  //
  // Dedupe: cloud-ul primeste un eveniment NOU doar daca codul nu a
  // fost vazut in scan-ul precedent. Asta evita spam-ul (altfel
  // dashboard-ul s-ar umple de duplicate la fiecare 10s).

  Timer? _pollTimer;
  ObdService? _pollService;
  bool _autoPolling = false;
  bool get isAutoPolling => _autoPolling;

  /// Codurile vazute la scan-ul precedent (pentru dedupe la cloud).
  final Set<String> _previouslySeenCodes = {};

  static const int _pollIntervalMs = 8000;

  /// Porneste auto-polling pentru DTC-uri. Idempotent — re-apelarea cu
  /// acelasi service nu duplica timer-ul.
  void startAutoPoll(ObdService service) {
    if (_autoPolling && _pollService == service) return;
    _pollTimer?.cancel();
    _pollService = service;
    _autoPolling = true;
    notifyListeners();
    // Trigger un scan imediat ca utilizatorul sa vada raspuns rapid.
    _autoTick();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _autoTick(),
    );
  }

  void stopAutoPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollService = null;
    _autoPolling = false;
    _previouslySeenCodes.clear();
    notifyListeners();
  }

  Future<void> _autoTick() async {
    final svc = _pollService;
    if (svc == null) return;
    // Daca user-ul ruleaza un scan manual exact acum, sare peste tick.
    if (_scanning) return;
    try {
      await _scanInternal(svc, source: 'auto');
    } catch (e) {
      if (kDebugMode) print('[DiagnosticsProvider] auto-poll failed: $e');
    }
  }

  // ===========================================================
  // SCAN (manual + auto)
  // ===========================================================

  Future<void> scan(ObdService service) async {
    await _scanInternal(service, source: 'manual');
  }

  Future<void> _scanInternal(
    ObdService service, {
    required String source,
  }) async {
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      _stored = await service.readStoredDtcs();
      _pending = await service.readPendingDtcs();
      _permanent = await service.readPermanentDtcs();
      _lastScan = DateTime.now();

      // Demo injection: adauga 2 DTC-uri fake la cele primite de la simulator
      // (vezi _kDemoStoredCodes). Dedupe-ul de mai jos asigura ca event-ul
      // cloud pleaca o singura data per sesiune, deci nu spamuieste.
      _stored = [..._buildDemoStored(), ..._stored];

      // Dedupe: trimite la cloud doar codurile NOI (nevazute la tick anterior)
      // sau toate (la scan manual, ca utilizatorul sa vada feedback).
      final currentCodes = {
        ..._stored.map((d) => 'stored:${d.code}'),
        ..._pending.map((d) => 'pending:${d.code}'),
      };

      // Stored — push catre cloud cei nevazuti la scan precedent (auto)
      // sau toti (manual).
      for (final d in _stored) {
        final key = 'stored:${d.code}';
        final isNew = !_previouslySeenCodes.contains(key);
        if (source == 'manual' || isNew) {
          await CloudSync.I.sendEvent(
            type: 'dtc',
            severity: 'critical',
            code: d.code,
            title: d.description,
            payload: {
              'status': 'stored',
              'category': d.category.label,
              'source': source,
            },
          );
        }
      }
      for (final d in _pending) {
        final key = 'pending:${d.code}';
        final isNew = !_previouslySeenCodes.contains(key);
        if (source == 'manual' || isNew) {
          await CloudSync.I.sendEvent(
            type: 'dtc',
            severity: 'warning',
            code: d.code,
            title: d.description,
            payload: {'status': 'pending', 'source': source},
          );
        }
      }

      _previouslySeenCodes
        ..clear()
        ..addAll(currentCodes);
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Construieste obiectele Dtc pentru codurile demo, cu descrieri preluate
  /// din [DtcDatabase] ca sa apara corect in UI si in eventul cloud.
  List<Dtc> _buildDemoStored() {
    final now = DateTime.now();
    return _kDemoStoredCodes.map((code) {
      final info = DtcDatabase.lookup(code);
      return Dtc(
        code: code,
        severity: DtcSeverity.confirmed,
        category: DtcCategory.fromLetter(code[0]),
        description: info.description,
        consequence: info.consequence,
        remedy: info.remedy,
        ecu: 'ECM',
        detectedAt: now,
      );
    }).toList();
  }

  Future<bool> clear(ObdService service) async {
    final ok = await service.clearDtcs();
    if (ok) {
      _stored = [];
      _pending = [];
      _previouslySeenCodes.clear();
      await CloudSync.I.sendEvent(
        type: 'dtc_cleared',
        severity: 'info',
        title: 'DTC-uri sterse (Mode 04)',
      );
      notifyListeners();
    }
    return ok;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
