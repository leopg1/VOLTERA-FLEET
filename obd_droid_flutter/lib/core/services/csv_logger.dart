import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pid.dart';

/// Streams PID samples to a timestamped CSV file in the app documents folder.
class CsvLogger {
  IOSink? _sink;
  String? _path;
  final List<Pid> pids;
  bool _wroteHeader = false;

  CsvLogger({required this.pids});

  String? get path => _path;
  bool get isLogging => _sink != null;

  Future<File> start({String? sessionName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/obd_logs');
    if (!await logsDir.exists()) await logsDir.create(recursive: true);

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final name = sessionName ?? 'session_$stamp';
    final file = File('${logsDir.path}/$name.csv');
    _sink = file.openWrite();
    _path = file.path;
    _wroteHeader = false;
    return file;
  }

  void log(Map<Pid, PidSample?> snapshot,
      {double? lat, double? lon, double? speedMs}) {
    final sink = _sink;
    if (sink == null) return;

    if (!_wroteHeader) {
      final header = [
        'timestamp_ms',
        'lat',
        'lon',
        'gps_speed_ms',
        ...pids.map((p) => p.shortName)
      ];
      sink.writeln(const ListToCsvConverter().convert([header]));
      _wroteHeader = true;
    }

    final row = <dynamic>[
      DateTime.now().millisecondsSinceEpoch,
      lat ?? '',
      lon ?? '',
      speedMs ?? '',
      ...pids.map((p) => snapshot[p]?.value ?? ''),
    ];
    sink.writeln(const ListToCsvConverter().convert([row]));
  }

  Future<File?> stop() async {
    final sink = _sink;
    final p = _path;
    if (sink == null || p == null) return null;
    await sink.flush();
    await sink.close();
    _sink = null;
    _path = null;
    return File(p);
  }
}
