import 'package:flutter/foundation.dart';

import '../core/models/dtc.dart';
import '../core/obd/obd_service.dart';
import '../core/services/cloud_sync.dart';

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

  Future<void> scan(ObdService service) async {
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      _stored = await service.readStoredDtcs();
      _pending = await service.readPendingDtcs();
      _permanent = await service.readPermanentDtcs();
      _lastScan = DateTime.now();

      // Push catre cloud — fiecare DTC devine event de severitate 'critical'.
      for (final d in _stored) {
        await CloudSync.I.sendEvent(
          type: 'dtc',
          severity: 'critical',
          code: d.code,
          title: d.description,
          payload: {
            'status': 'stored',
            'category': d.category.label,
          },
        );
      }
      for (final d in _pending) {
        await CloudSync.I.sendEvent(
          type: 'dtc',
          severity: 'warning',
          code: d.code,
          title: d.description,
          payload: {'status': 'pending'},
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<bool> clear(ObdService service) async {
    final ok = await service.clearDtcs();
    if (ok) {
      _stored = [];
      _pending = [];
      await CloudSync.I.sendEvent(
        type: 'dtc_cleared',
        severity: 'info',
        title: 'DTC-uri sterse (Mode 04)',
      );
      notifyListeners();
    }
    return ok;
  }
}
