import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../connection/obd_transport.dart';
import '../models/connection_state.dart';
import '../models/obd_protocol.dart';

/// Result of a single ELM327 round-trip.
class ElmResponse {
  final String command;
  final String raw;
  final List<String> lines;
  final bool isError;
  final String? error;

  ElmResponse({
    required this.command,
    required this.raw,
    required this.lines,
    this.isError = false,
    this.error,
  });

  /// All response lines parsed into byte arrays. Empty if the response was an
  /// ELM error string (NO DATA, ?, BUS BUSY, ...).
  List<List<int>> get bytes {
    if (isError) return const [];
    final out = <List<int>>[];
    for (final line in lines) {
      // Skip lines like "SEARCHING..." or BUS INIT messages
      if (line.toUpperCase().contains('SEARCHING')) continue;
      if (line.toUpperCase().contains('BUS INIT')) continue;
      final clean = line.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      final row = <int>[];
      for (var i = 0; i + 1 < clean.length; i += 2) {
        final v = int.tryParse(clean.substring(i, i + 2), radix: 16);
        if (v != null) row.add(v);
      }
      if (row.isNotEmpty) out.add(row);
    }
    return out;
  }
}

/// One entry in the ELM327 communication log (used by the diagnostic terminal).
class ElmLogEntry {
  final DateTime time;
  final String direction; // 'TX' | 'RX' | 'INFO' | 'ERR'
  final String text;
  ElmLogEntry(this.direction, this.text) : time = DateTime.now();
}

/// Speaks the AT command dialect of an ELM327 (or compatible) adapter.
class ElmEngine {
  final ObdTransport transport;

  StreamSubscription<Uint8List>? _sub;
  final _buffer = StringBuffer();
  Completer<String>? _pending;

  ObdLinkState _state = ObdLinkState.disconnected;
  ObdLinkState get state => _state;
  final _stateCtrl = StreamController<ObdLinkState>.broadcast();
  Stream<ObdLinkState> get stateStream => _stateCtrl.stream;

  final Queue<ElmLogEntry> _log = Queue<ElmLogEntry>();
  final _logCtrl = StreamController<ElmLogEntry>.broadcast();
  Stream<ElmLogEntry> get logStream => _logCtrl.stream;
  List<ElmLogEntry> get log => List.unmodifiable(_log);

  String? _firmware;
  String? get firmware => _firmware;

  ObdProtocol? _negotiatedProtocol;
  ObdProtocol? get negotiatedProtocol => _negotiatedProtocol;

  ElmEngine(this.transport);

  void _appendLog(String dir, String text) {
    final e = ElmLogEntry(dir, text);
    _log.addLast(e);
    while (_log.length > 200) {
      _log.removeFirst();
    }
    if (!_logCtrl.isClosed) _logCtrl.add(e);
  }

  Future<void> open() async {
    _setState(ObdLinkState.connecting);
    _appendLog('INFO', 'Opening transport...');
    await transport.connect();
    _appendLog('INFO', 'Transport connected.');
    _sub = transport.incoming.listen(_onBytes, onError: (e) {
      _appendLog('ERR', 'Transport error: $e');
    });
    _setState(ObdLinkState.initializing);
    await _initialize();
    _setState(ObdLinkState.ready);
    _appendLog('INFO', 'Engine ready.');
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await transport.disconnect();
    } catch (_) {}
    _setState(ObdLinkState.disconnected);
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
    if (!_logCtrl.isClosed) await _logCtrl.close();
  }

  void _setState(ObdLinkState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  Future<void> _initialize() async {
    // 1. Reset (give it 5 seconds to come back)
    final reset = await sendRaw('ATZ', timeout: const Duration(seconds: 6));
    _firmware = reset.lines.firstWhere(
      (l) => l.toUpperCase().contains('ELM'),
      orElse: () => reset.lines.isNotEmpty ? reset.lines.last : 'Unknown',
    );

    // 2-7. Configurare standard
    await sendRaw('ATE0'); // echo off
    await sendRaw('ATL0'); // linefeed off
    await sendRaw('ATS0'); // spaces off
    await sendRaw('ATH0'); // headers off
    await sendRaw('ATAT1'); // adaptive timing
    await sendRaw('ATSP0'); // auto protocol

    // 8. Probe protocol
    final probe = await sendRaw('0100', timeout: const Duration(seconds: 8));
    if (!probe.isError) {
      final dpn = await sendRaw('ATDPN');
      _negotiatedProtocol = _parseProtocolNumber(dpn.raw);
      _appendLog('INFO',
          'Protocol negotiated: ${_negotiatedProtocol?.label ?? "unknown"}');
    } else {
      _appendLog('ERR', 'Protocol probe failed: ${probe.error}');
    }
  }

  ObdProtocol? _parseProtocolNumber(String s) {
    final trimmed = s.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (trimmed.isEmpty) return null;
    final last = int.tryParse(trimmed, radix: 16);
    if (last == null) return null;
    final id = last & 0x0F;
    return ObdProtocol.values.firstWhere(
      (p) => p.id == id,
      orElse: () => ObdProtocol.auto,
    );
  }

  /// Public API for the diagnostic terminal — send any command.
  Future<ElmResponse> sendRaw(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    while (_pending != null) {
      try {
        await _pending!.future;
      } catch (_) {/* ignore */}
    }

    final completer = Completer<String>();
    _pending = completer;
    _buffer.clear();

    final payload = '$command\r';
    _appendLog('TX', command);
    try {
      await transport.send(Uint8List.fromList(ascii.encode(payload)));
    } catch (e) {
      _pending = null;
      _appendLog('ERR', 'Send failed: $e');
      return ElmResponse(
          command: command,
          raw: '',
          lines: const [],
          isError: true,
          error: 'SEND_FAILED');
    }

    String raw;
    try {
      raw = await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending = null;
      _appendLog('ERR', 'Timeout waiting for $command');
      return ElmResponse(
          command: command,
          raw: '',
          lines: const [],
          isError: true,
          error: 'TIMEOUT');
    } finally {
      _pending = null;
    }

    final cleaned = raw
        .replaceAll('\r\r', '\r')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != '>')
        .toList();

    _appendLog('RX', cleaned.join(' | '));

    final upperJoined = cleaned.join(' ').toUpperCase();
    final errors = [
      'NO DATA',
      'BUS BUSY',
      'BUS ERROR',
      'CAN ERROR',
      'STOPPED',
      'UNABLE TO CONNECT',
      'ERROR'
    ];
    final hit = errors.firstWhere(
      (e) => upperJoined.contains(e),
      orElse: () => '',
    );
    return ElmResponse(
      command: command,
      raw: raw,
      lines: cleaned,
      isError: hit.isNotEmpty,
      error: hit.isEmpty ? null : hit,
    );
  }

  void _onBytes(Uint8List bytes) {
    _buffer.write(ascii.decode(bytes, allowInvalid: true));
    final s = _buffer.toString();
    if (s.contains('>')) {
      final raw = s.substring(0, s.indexOf('>'));
      _pending?.complete(raw);
      _buffer.clear();
    }
  }
}
