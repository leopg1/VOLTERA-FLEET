import 'dart:async';

import '../models/dtc.dart';
import '../models/pid.dart';
import '../services/dtc_database.dart';
import 'elm_engine.dart';

/// High-level OBD-II diagnostics service that builds on [ElmEngine].
///
/// Provides ergonomic methods such as [readPid], [readDtcs], and [readVin]
/// without leaking ELM word-soup to the UI layer.
class ObdService {
  final ElmEngine engine;

  ObdService(this.engine);

  /// Issues an OBD request (e.g. `01 0C`) and decodes the response data bytes.
  Future<List<int>?> _request(String hexCommand) async {
    final res = await engine.sendRaw(hexCommand);
    if (res.isError) return null;

    // First two bytes echo (mode + PID); we strip them off when present.
    final all = res.bytes;
    if (all.isEmpty) return null;
    final flat = all.expand((row) => row).toList();
    if (flat.length < 2) return flat;

    // For mode 01, response starts with 0x40+mode (0x41) and the PID byte.
    final reqMode = int.tryParse(hexCommand.substring(0, 2), radix: 16) ?? 0;
    final reqPid = hexCommand.length >= 4
        ? int.tryParse(hexCommand.substring(2, 4), radix: 16)
        : null;
    if (flat[0] == 0x40 + reqMode && (reqPid == null || flat[1] == reqPid)) {
      return flat.sublist(2);
    }
    return flat;
  }

  /// Reads a single PID (e.g. RPM, speed) and returns a [PidSample].
  Future<PidSample?> readPid(Pid pid) async {
    final data = await _request(pid.request);
    if (data == null || data.length < pid.bytes) return null;
    final value = pid.decode(data.sublist(0, pid.bytes));
    return PidSample(pid: pid, value: value, timestamp: DateTime.now());
  }

  /// Reads stored DTCs (mode 03).
  Future<List<Dtc>> readStoredDtcs() => _readDtcs('03', DtcSeverity.confirmed);

  /// Reads pending DTCs (mode 07).
  Future<List<Dtc>> readPendingDtcs() => _readDtcs('07', DtcSeverity.pending);

  /// Reads permanent DTCs (mode 0A).
  Future<List<Dtc>> readPermanentDtcs() => _readDtcs('0A', DtcSeverity.permanent);

  /// Sends Mode 04 — clears emissions DTCs and resets MIL.
  Future<bool> clearDtcs() async {
    final res = await engine.sendRaw('04', timeout: const Duration(seconds: 5));
    return !res.isError;
  }

  Future<List<Dtc>> _readDtcs(String mode, DtcSeverity severity) async {
    final data = await _request(mode);
    if (data == null || data.isEmpty) return const [];
    // First byte after mode echo = number of DTCs * 2 bytes per code.
    // We've stripped the mode echo in [_request], so first byte is the count.
    final count = data.first;
    final bytes = data.sublist(1);
    final out = <Dtc>[];
    for (var i = 0; i + 1 < bytes.length && out.length < count; i += 2) {
      final hi = bytes[i];
      final lo = bytes[i + 1];
      if (hi == 0 && lo == 0) continue;
      final code = Dtc.decodeRaw(hi, lo);
      final info = DtcDatabase.lookup(code);
      out.add(Dtc(
        code: code,
        severity: severity,
        category: DtcCategory.fromLetter(code.substring(0, 1)),
        description: info.description,
        consequence: info.consequence,
        remedy: info.remedy,
        detectedAt: DateTime.now(),
      ));
    }
    return out;
  }

  /// Reads the 17-character Vehicle Identification Number (Mode 09 PID 02).
  ///
  /// VIN comes back as a multi-frame ISO-TP response. The ELM strips frame
  /// counters when ATH0 is on, so we just collect ASCII bytes.
  Future<String?> readVin() async {
    final res = await engine.sendRaw('0902', timeout: const Duration(seconds: 5));
    if (res.isError) return null;
    final flat = res.bytes.expand((b) => b).toList();
    final ascii = <int>[];
    for (var i = 0; i < flat.length; i++) {
      final b = flat[i];
      if (b >= 0x30 && b <= 0x5A) ascii.add(b);
    }
    if (ascii.length < 17) return null;
    final vin = String.fromCharCodes(ascii.sublist(ascii.length - 17));
    return vin.length == 17 ? vin : null;
  }

  /// Reads supported PIDs from the ECU (Mode 01 PID 00, 20, 40, 60, 80).
  Future<Set<int>> readSupportedPids() async {
    final supported = <int>{};
    for (final base in [0x00, 0x20, 0x40, 0x60, 0x80, 0xA0, 0xC0]) {
      final cmd = '01${base.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final data = await _request(cmd);
      if (data == null || data.length < 4) break;
      final bitfield = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      for (var i = 0; i < 32; i++) {
        if ((bitfield & (1 << (31 - i))) != 0) {
          supported.add(base + i + 1);
        }
      }
      // If "next bank supported" bit is not set, stop.
      if ((data[3] & 0x01) == 0) break;
    }
    return supported;
  }
}
