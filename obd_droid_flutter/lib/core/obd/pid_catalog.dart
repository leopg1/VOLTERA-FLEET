import '../models/pid.dart';

/// Standard SAE J1979 PID catalog (Mode 01).
class PidCatalog {
  PidCatalog._();

  static Map<int, Pid> get mode01 => {
        0x04: Pid(
          mode: 0x01, code: 0x04,
          name: 'Engine Load', shortName: 'LOAD',
          unit: '%', bytes: 1, min: 0, max: 100,
          decoder: (d) => d[0] * 100 / 255,
        ),
        0x05: Pid(
          mode: 0x01, code: 0x05,
          name: 'Coolant Temperature', shortName: 'ECT',
          unit: '°C', bytes: 1, min: -40, max: 215,
          decoder: (d) => d[0].toDouble() - 40,
        ),
        0x06: Pid(
          mode: 0x01, code: 0x06,
          name: 'Short Term Fuel Trim B1', shortName: 'STFT1',
          unit: '%', bytes: 1, min: -100, max: 99.2,
          decoder: (d) => (d[0] - 128) * 100 / 128,
        ),
        0x07: Pid(
          mode: 0x01, code: 0x07,
          name: 'Long Term Fuel Trim B1', shortName: 'LTFT1',
          unit: '%', bytes: 1, min: -100, max: 99.2,
          decoder: (d) => (d[0] - 128) * 100 / 128,
        ),
        0x0A: Pid(
          mode: 0x01, code: 0x0A,
          name: 'Fuel Pressure', shortName: 'FP',
          unit: 'kPa', bytes: 1, min: 0, max: 765,
          decoder: (d) => d[0] * 3.0,
        ),
        0x0B: Pid(
          mode: 0x01, code: 0x0B,
          name: 'Intake Manifold Pressure', shortName: 'MAP',
          unit: 'kPa', bytes: 1, min: 0, max: 255,
          decoder: (d) => d[0].toDouble(),
        ),
        0x0C: Pid(
          mode: 0x01, code: 0x0C,
          name: 'Engine RPM', shortName: 'RPM',
          unit: 'rpm', bytes: 2, min: 0, max: 16383.75,
          decoder: (d) => (d[0] * 256 + d[1]) / 4.0,
        ),
        0x0D: Pid(
          mode: 0x01, code: 0x0D,
          name: 'Vehicle Speed', shortName: 'SPD',
          unit: 'km/h', bytes: 1, min: 0, max: 255,
          decoder: (d) => d[0].toDouble(),
        ),
        0x0E: Pid(
          mode: 0x01, code: 0x0E,
          name: 'Timing Advance', shortName: 'TIM',
          unit: '°', bytes: 1, min: -64, max: 63.5,
          decoder: (d) => d[0] / 2.0 - 64,
        ),
        0x0F: Pid(
          mode: 0x01, code: 0x0F,
          name: 'Intake Air Temperature', shortName: 'IAT',
          unit: '°C', bytes: 1, min: -40, max: 215,
          decoder: (d) => d[0].toDouble() - 40,
        ),
        0x10: Pid(
          mode: 0x01, code: 0x10,
          name: 'Mass Air Flow', shortName: 'MAF',
          unit: 'g/s', bytes: 2, min: 0, max: 655.35,
          decoder: (d) => (d[0] * 256 + d[1]) / 100.0,
        ),
        0x11: Pid(
          mode: 0x01, code: 0x11,
          name: 'Throttle Position', shortName: 'TPS',
          unit: '%', bytes: 1, min: 0, max: 100,
          decoder: (d) => d[0] * 100 / 255,
        ),
        0x1F: Pid(
          mode: 0x01, code: 0x1F,
          name: 'Run Time Since Engine Start', shortName: 'RUN',
          unit: 's', bytes: 2, min: 0, max: 65535,
          decoder: (d) => (d[0] * 256 + d[1]).toDouble(),
        ),
        0x21: Pid(
          mode: 0x01, code: 0x21,
          name: 'Distance With MIL On', shortName: 'DMIL',
          unit: 'km', bytes: 2, min: 0, max: 65535,
          decoder: (d) => (d[0] * 256 + d[1]).toDouble(),
        ),
        0x2F: Pid(
          mode: 0x01, code: 0x2F,
          name: 'Fuel Level', shortName: 'FUEL',
          unit: '%', bytes: 1, min: 0, max: 100,
          decoder: (d) => d[0] * 100 / 255,
        ),
        0x33: Pid(
          mode: 0x01, code: 0x33,
          name: 'Barometric Pressure', shortName: 'BARO',
          unit: 'kPa', bytes: 1, min: 0, max: 255,
          decoder: (d) => d[0].toDouble(),
        ),
        0x42: Pid(
          mode: 0x01, code: 0x42,
          name: 'Control Module Voltage', shortName: 'BAT',
          unit: 'V', bytes: 2, min: 0, max: 65.535,
          decoder: (d) => (d[0] * 256 + d[1]) / 1000.0,
        ),
        0x46: Pid(
          mode: 0x01, code: 0x46,
          name: 'Ambient Air Temperature', shortName: 'AAT',
          unit: '°C', bytes: 1, min: -40, max: 215,
          decoder: (d) => d[0].toDouble() - 40,
        ),
        0x5C: Pid(
          mode: 0x01, code: 0x5C,
          name: 'Engine Oil Temperature', shortName: 'EOT',
          unit: '°C', bytes: 1, min: -40, max: 215,
          decoder: (d) => d[0].toDouble() - 40,
        ),
      };

  static List<Pid> get dashboardDefaults {
    final m = mode01;
    return [
      m[0x0C]!, // RPM
      m[0x0D]!, // Speed
      m[0x05]!, // Coolant temp
      m[0x11]!, // Throttle
      m[0x04]!, // Engine load (Calculated load)
      m[0x0B]!, // Intake manifold pressure (MAP)
      m[0x0F]!, // IAT
      m[0x10]!, // MAF
      m[0x42]!, // Battery
      m[0x2F]!, // Fuel level
    ];
  }

  static Pid? lookup(int code) => mode01[code];
}
