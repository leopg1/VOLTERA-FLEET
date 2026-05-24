/// A single OBD-II Parameter Identifier (PID) descriptor.
class Pid {
  final int mode;
  final int code;
  final String name;
  final String shortName;
  final String unit;
  final int bytes;
  final double Function(List<int> data) decoder;
  final double min;
  final double max;
  final String category;

  Pid({
    required this.mode,
    required this.code,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.bytes,
    required this.decoder,
    required this.min,
    required this.max,
    this.category = 'engine',
  });

  @override
  bool operator ==(Object other) => other is Pid && other.code == code && other.mode == mode;

  @override
  int get hashCode => Object.hash(mode, code);

  /// Returns the request bytes ("01 0C", "01 0D", etc).
  String get request {
    final m = mode.toRadixString(16).padLeft(2, '0').toUpperCase();
    final c = code.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$m$c';
  }

  /// Decodes the response data into a numerical value.
  double decode(List<int> data) => decoder(data);

  @override
  String toString() => '$name (PID 0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()})';
}

/// A snapshot of a PID value at a specific moment in time.
class PidSample {
  final Pid pid;
  final double value;
  final DateTime timestamp;

  PidSample({
    required this.pid,
    required this.value,
    required this.timestamp,
  });

  String get formatted {
    if (value.isNaN || value.isInfinite) return '—';
    final precision = pid.unit == '%' ? 1 : (pid.max > 100 ? 0 : 2);
    return '${value.toStringAsFixed(precision)} ${pid.unit}';
  }
}
