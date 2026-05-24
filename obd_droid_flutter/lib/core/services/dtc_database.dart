/// Comprehensive catalog of common SAE J2012 Diagnostic Trouble Codes (DTCs).
///
/// Provides human-readable descriptions, severity hints and likely remedies for
/// the most frequently encountered powertrain (P), body (B), chassis (C) and
/// network (U) codes. The dataset is intentionally embedded so the application
/// works 100% offline on a tablet without any network access.
///
/// Coverage: ~220 entries spanning the most common SAE-defined codes plus a
/// generic-fallback strategy that produces a sensible explanation for codes
/// that are not in the table.
library;

class DtcInfo {
  final String code;
  final String description;
  final String? consequence;
  final String? remedy;
  final DtcImpact impact;
  final String system;

  const DtcInfo({
    required this.code,
    required this.description,
    required this.system,
    required this.impact,
    this.consequence,
    this.remedy,
  });
}

/// Severity classification — used to color-code cards and prioritize repairs.
enum DtcImpact { critical, high, medium, low }

class DtcDatabase {
  DtcDatabase._();

  static final Map<String, DtcInfo> _db = _seed();

  static DtcInfo lookup(String code) {
    final c = code.toUpperCase().trim();
    final hit = _db[c];
    if (hit != null) return hit;
    return _generic(c);
  }

  /// Best-effort fallback when the exact code is not in the table.
  static DtcInfo _generic(String code) {
    if (code.isEmpty) {
      return const DtcInfo(
        code: '----',
        description: 'Cod necunoscut',
        system: 'Unknown',
        impact: DtcImpact.medium,
      );
    }
    final letter = code[0];
    final system = switch (letter) {
      'P' => 'Powertrain',
      'B' => 'Body',
      'C' => 'Chassis',
      'U' => 'Network',
      _ => 'Unknown',
    };
    final isMfr = code.length >= 2 && (code[1] == '1' || code[1] == '3');
    return DtcInfo(
      code: code,
      description: isMfr
          ? 'Cod specific producatorului ($system)'
          : 'Cod generic $system — neacoperit in baza de date locala',
      system: system,
      impact: DtcImpact.medium,
      consequence:
          'Codul este valid OBD-II dar nu avem o descriere detaliata. '
          'Foloseste manualul vehiculului sau scaneaza prin Mode 03 + Freeze Frame.',
      remedy:
          'Verifica in manualul de service al vehiculului. '
          'Codurile $letter${isMfr ? "1xxx/3xxx" : "0xxx/2xxx"} indica '
          'subsistemul ${system.toLowerCase()}.',
    );
  }

  static List<DtcInfo> all() => _db.values.toList(growable: false);

  static Map<String, DtcInfo> _seed() {
    final List<DtcInfo> codes = [
      // ============================ FUEL & AIR ============================
      const DtcInfo(
        code: 'P0100',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'Mass Air Flow (MAF) Circuit Malfunction',
        consequence:
            'Mers neregulat, consum crescut, pierdere de putere si posibile rateuri.',
        remedy:
            'Curata senzorul MAF cu spray dedicat, verifica firele si '
            'conectorul, controleaza filtrul de aer si garniturile de admisie.',
      ),
      const DtcInfo(
        code: 'P0101',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAF Sensor Range/Performance',
        consequence:
            'Valori MAF in afara intervalului — posibil mix bogat sau sarac.',
        remedy:
            'Inspecteaza filtrul de aer si galeria de admisie pentru '
            'scurgeri (vacuum leak). Curata senzorul MAF; daca problema persista, '
            'inlocuieste-l.',
      ),
      const DtcInfo(
        code: 'P0102',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAF Circuit Low Input',
        consequence: 'Aer insuficient masurat — combustia este afectata.',
        remedy:
            'Verifica conectorul si masa senzorului MAF. Inlocuieste '
            'senzorul daca semnalul ramane jos.',
      ),
      const DtcInfo(
        code: 'P0103',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAF Circuit High Input',
        consequence: 'Semnal MAF prea mare — risc de mers neregulat.',
        remedy: 'Curata sau inlocuieste senzorul MAF; verifica cabajul.',
      ),
      const DtcInfo(
        code: 'P0106',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAP/Barometric Pressure Range/Performance',
        consequence: 'Calculul aerului admis este incorect.',
        remedy:
            'Verifica furtunul de vacuum la senzorul MAP, conectorul si '
            'inlocuieste senzorul daca este defect.',
      ),
      const DtcInfo(
        code: 'P0107',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAP/Barometric Pressure Low Input',
        remedy: 'Inspecteaza cabajul MAP si inlocuieste senzorul daca e cazul.',
      ),
      const DtcInfo(
        code: 'P0108',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'MAP/Barometric Pressure High Input',
        remedy: 'Verifica scurgerile de vacuum si conectorul MAP.',
      ),
      const DtcInfo(
        code: 'P0110',
        system: 'Fuel & Air',
        impact: DtcImpact.medium,
        description: 'Intake Air Temperature (IAT) Sensor Circuit Malfunction',
        remedy: 'Verifica firele IAT, curata si reinstaleaza sau inlocuieste.',
      ),
      const DtcInfo(
        code: 'P0112',
        system: 'Fuel & Air',
        impact: DtcImpact.medium,
        description: 'IAT Sensor Circuit Low Input',
        remedy: 'Inspecteaza scurtcircuit la masa pe firul IAT.',
      ),
      const DtcInfo(
        code: 'P0113',
        system: 'Fuel & Air',
        impact: DtcImpact.medium,
        description: 'IAT Sensor Circuit High Input',
        remedy:
            'Verifica conectorul IAT si masura rezistenta. Inlocuieste senzorul.',
      ),
      const DtcInfo(
        code: 'P0115',
        system: 'Cooling',
        impact: DtcImpact.high,
        description: 'Engine Coolant Temperature (ECT) Sensor Circuit',
        consequence: 'ECU nu cunoaste temperatura motorului.',
        remedy: 'Verifica senzorul ECT, conectorul si firele aferente.',
      ),
      const DtcInfo(
        code: 'P0116',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'ECT Sensor Range/Performance',
        remedy: 'Scoate si testeaza senzorul ECT cu apa calda + multimetru.',
      ),
      const DtcInfo(
        code: 'P0117',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'ECT Sensor Circuit Low Input',
        remedy: 'Inlocuieste senzorul ECT sau remediaza scurtcircuit la masa.',
      ),
      const DtcInfo(
        code: 'P0118',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'ECT Sensor Circuit High Input',
        remedy: 'Verifica firele ECT si conectorul; inlocuieste senzorul.',
      ),
      const DtcInfo(
        code: 'P0120',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'Throttle/Pedal Position Sensor "A" Circuit',
        consequence: 'Limitator de putere (limp mode).',
        remedy:
            'Curata clapeta, verifica senzorul TPS si conectorul. Reset adaptari.',
      ),
      const DtcInfo(
        code: 'P0121',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'Throttle Position Sensor "A" Range/Performance',
        remedy: 'Calibreaza/reseteaza clapeta dupa curatare.',
      ),
      const DtcInfo(
        code: 'P0122',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'TPS "A" Low Input',
        remedy: 'Verifica firul de semnal TPS pentru scurtcircuit la masa.',
      ),
      const DtcInfo(
        code: 'P0123',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'TPS "A" High Input',
        remedy: 'Inspecteaza alimentarea +5V a TPS si firul de semnal.',
      ),
      const DtcInfo(
        code: 'P0128',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'Coolant Temperature Below Thermostat Regulating Temperature',
        consequence: 'Motorul nu atinge temperatura optima — consum crescut.',
        remedy: 'Inlocuieste termostatul; verifica senzorul ECT.',
      ),
      const DtcInfo(
        code: 'P0130',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit (Bank 1, Sensor 1)',
        remedy: 'Verifica firele si conectorul sondei lambda; curata sau inlocuieste.',
      ),
      const DtcInfo(
        code: 'P0131',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit Low Voltage (B1S1)',
        consequence: 'Mix prea sarac detectat.',
        remedy: 'Inspecteaza scurgerile de admisie si presiunea combustibilului.',
      ),
      const DtcInfo(
        code: 'P0132',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit High Voltage (B1S1)',
        consequence: 'Mix prea bogat detectat.',
        remedy:
            'Verifica injectoarele pentru scurgeri si presiunea combustibilului '
            '(regulator/pompa).',
      ),
      const DtcInfo(
        code: 'P0133',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Slow Response (B1S1)',
        consequence: 'Eficienta combustiei scazuta, consum si emisii crescute.',
        remedy: 'Inlocuieste sonda lambda B1S1.',
      ),
      const DtcInfo(
        code: 'P0134',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor No Activity Detected (B1S1)',
        remedy:
            'Verifica incalzirea (heater) sondei si conexiunile electrice. '
            'Inlocuieste daca semnalul ramane plat.',
      ),
      const DtcInfo(
        code: 'P0135',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Heater Circuit (B1S1)',
        remedy: 'Inlocuieste sonda lambda — circuitul de incalzire este defect.',
      ),
      const DtcInfo(
        code: 'P0136',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit (Bank 1, Sensor 2)',
        remedy: 'Verifica conexiunile sondei post-cat si inlocuieste daca e defecta.',
      ),
      const DtcInfo(
        code: 'P0137',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit Low Voltage (B1S2)',
        remedy: 'Inspecteaza cabajul si conectorul B1S2.',
      ),
      const DtcInfo(
        code: 'P0138',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit High Voltage (B1S2)',
        remedy: 'Verifica scurgerile de combustibil sau injectoare deteriorate.',
      ),
      const DtcInfo(
        code: 'P0139',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Slow Response (B1S2)',
        remedy: 'Verifica catalizatorul si sonda B1S2.',
      ),
      const DtcInfo(
        code: 'P0140',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor No Activity (B1S2)',
        remedy: 'Inlocuieste sonda lambda B1S2.',
      ),
      const DtcInfo(
        code: 'P0141',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Heater Circuit (B1S2)',
        remedy: 'Inlocuieste sonda B1S2 sau remediaza alimentarea heater.',
      ),
      const DtcInfo(
        code: 'P0150',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit (B2S1)',
        remedy: 'Inspecteaza conexiunile si inlocuieste sonda daca e cazul.',
      ),
      const DtcInfo(
        code: 'P0151',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Low Voltage (B2S1)',
        remedy: 'Verifica scurgeri vacuum si presiunea combustibilului.',
      ),
      const DtcInfo(
        code: 'P0152',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor High Voltage (B2S1)',
        remedy: 'Verifica injectoarele si presiunea combustibilului.',
      ),
      const DtcInfo(
        code: 'P0153',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Slow Response (B2S1)',
        remedy: 'Inlocuieste sonda B2S1.',
      ),
      const DtcInfo(
        code: 'P0154',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor No Activity (B2S1)',
        remedy: 'Verifica heater-ul si conexiunile sondei.',
      ),
      const DtcInfo(
        code: 'P0155',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Heater Circuit (B2S1)',
        remedy: 'Inlocuieste sonda B2S1 — circuitul de incalzire este defect.',
      ),
      const DtcInfo(
        code: 'P0156',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Circuit (B2S2)',
        remedy: 'Verifica conexiunile sondei post-cat banc 2.',
      ),
      const DtcInfo(
        code: 'P0157',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Low Voltage (B2S2)',
      ),
      const DtcInfo(
        code: 'P0158',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor High Voltage (B2S2)',
      ),
      const DtcInfo(
        code: 'P0159',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Slow Response (B2S2)',
      ),
      const DtcInfo(
        code: 'P0160',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor No Activity (B2S2)',
      ),
      const DtcInfo(
        code: 'P0161',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Heater Circuit (B2S2)',
      ),
      const DtcInfo(
        code: 'P0170',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'Fuel Trim Malfunction (Bank 1)',
        consequence: 'ECU nu poate corecta amestecul.',
        remedy:
            'Verifica scurgerile de aer (vacuum leaks), MAF, presiunea '
            'pompei de combustibil si filtrul.',
      ),
      const DtcInfo(
        code: 'P0171',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'System Too Lean (Bank 1)',
        consequence: 'Mers neregulat, posibile rateuri si daune catalizator.',
        remedy:
            'Cauta scurgeri de aer pe galeria de admisie, verifica MAF, '
            'pompa si filtrul de combustibil.',
      ),
      const DtcInfo(
        code: 'P0172',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'System Too Rich (Bank 1)',
        consequence: 'Consum crescut, fum negru, miros de benzina.',
        remedy:
            'Verifica injectoarele (scurgeri), regulatorul de presiune, '
            'sonda lambda si filtrul de aer.',
      ),
      const DtcInfo(
        code: 'P0173',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'Fuel Trim Malfunction (Bank 2)',
      ),
      const DtcInfo(
        code: 'P0174',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'System Too Lean (Bank 2)',
      ),
      const DtcInfo(
        code: 'P0175',
        system: 'Fuel Trim',
        impact: DtcImpact.high,
        description: 'System Too Rich (Bank 2)',
      ),
      const DtcInfo(
        code: 'P0181',
        system: 'Fuel & Air',
        impact: DtcImpact.medium,
        description: 'Fuel Temperature Sensor Range/Performance',
      ),
      const DtcInfo(
        code: 'P0190',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'Fuel Rail Pressure Sensor Circuit',
      ),
      const DtcInfo(
        code: 'P0191',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'Fuel Rail Pressure Sensor Range/Performance',
      ),
      const DtcInfo(
        code: 'P0192',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'Fuel Rail Pressure Sensor Low Input',
      ),
      const DtcInfo(
        code: 'P0193',
        system: 'Fuel & Air',
        impact: DtcImpact.high,
        description: 'Fuel Rail Pressure Sensor High Input',
      ),

      // ============================ MISFIRE ============================
      const DtcInfo(
        code: 'P0300',
        system: 'Ignition',
        impact: DtcImpact.critical,
        description: 'Random/Multiple Cylinder Misfire Detected',
        consequence:
            'Pierdere de putere, vibratii, posibile daune la catalizator.',
        remedy:
            'Verifica bujiile, bobinele de inductie, injectoarele, compresia '
            'cilindrilor si scurgerile de admisie.',
      ),
      for (var i = 1; i <= 12; i++)
        DtcInfo(
          code: 'P030${i.toRadixString(16).toUpperCase()}',
          system: 'Ignition',
          impact: DtcImpact.high,
          description: 'Cylinder $i Misfire Detected',
          consequence:
              'Cilindrul $i are rateuri — pierdere putere si risc cat. '
              '${i > 9 ? "" : ""}',
          remedy:
              'Inverseaza bujia si bobina cilindrului $i cu un cilindru sanatos. '
              'Daca codul migreaza, ai gasit componenta defecta. Verifica si injectorul.',
        ),

      // ============================ IGNITION ============================
      const DtcInfo(
        code: 'P0320',
        system: 'Ignition',
        impact: DtcImpact.high,
        description: 'Ignition/Distributor Engine Speed Input Circuit',
      ),
      const DtcInfo(
        code: 'P0335',
        system: 'Ignition',
        impact: DtcImpact.critical,
        description: 'Crankshaft Position Sensor "A" Circuit',
        consequence:
            'Motorul nu porneste sau se opreste. Limp mode garantat.',
        remedy: 'Inlocuieste senzorul CKP si verifica firele/conectorul.',
      ),
      const DtcInfo(
        code: 'P0336',
        system: 'Ignition',
        impact: DtcImpact.critical,
        description: 'Crankshaft Position Sensor "A" Range/Performance',
      ),
      const DtcInfo(
        code: 'P0340',
        system: 'Ignition',
        impact: DtcImpact.critical,
        description: 'Camshaft Position Sensor Circuit',
        consequence: 'Motor blocat in modul de avarie sau nu porneste.',
        remedy: 'Inlocuieste senzorul CMP, verifica firele si lantul de distributie.',
      ),
      const DtcInfo(
        code: 'P0341',
        system: 'Ignition',
        impact: DtcImpact.high,
        description: 'Camshaft Position Sensor Range/Performance',
      ),

      // ============================ EGR / EVAP ============================
      const DtcInfo(
        code: 'P0400',
        system: 'EGR',
        impact: DtcImpact.medium,
        description: 'Exhaust Gas Recirculation Flow',
        remedy: 'Curata supapa EGR si galeria; inlocuieste daca e blocata.',
      ),
      const DtcInfo(
        code: 'P0401',
        system: 'EGR',
        impact: DtcImpact.medium,
        description: 'EGR Insufficient Flow Detected',
        remedy: 'Curata sau inlocuieste valva EGR. Verifica conductele si vacuum.',
      ),
      const DtcInfo(
        code: 'P0402',
        system: 'EGR',
        impact: DtcImpact.medium,
        description: 'EGR Excessive Flow Detected',
      ),
      const DtcInfo(
        code: 'P0403',
        system: 'EGR',
        impact: DtcImpact.medium,
        description: 'EGR Control Circuit',
      ),
      const DtcInfo(
        code: 'P0420',
        system: 'Catalyst',
        impact: DtcImpact.medium,
        description: 'Catalyst System Efficiency Below Threshold (Bank 1)',
        consequence:
            'Catalizatorul nu mai curata gazele eficient. Inspectia tehnica va pica.',
        remedy:
            'Inlocuieste catalizatorul; verifica si sondele lambda inainte si dupa cat.',
      ),
      const DtcInfo(
        code: 'P0421',
        system: 'Catalyst',
        impact: DtcImpact.medium,
        description: 'Warm Up Catalyst Efficiency (Bank 1)',
      ),
      const DtcInfo(
        code: 'P0430',
        system: 'Catalyst',
        impact: DtcImpact.medium,
        description: 'Catalyst System Efficiency Below Threshold (Bank 2)',
        remedy: 'Inlocuieste catalizatorul B2 si verifica sondele lambda.',
      ),
      const DtcInfo(
        code: 'P0440',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP System Malfunction',
        remedy:
            'Strange busonul rezervorului. Daca persista, verifica '
            'electrovalvele EVAP si furtunurile.',
      ),
      const DtcInfo(
        code: 'P0441',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP Incorrect Purge Flow',
      ),
      const DtcInfo(
        code: 'P0442',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP System Small Leak Detected',
        remedy:
            'Strange bine busonul rezervorului. Inspecteaza furtunurile si '
            'electrovalvele EVAP.',
      ),
      const DtcInfo(
        code: 'P0443',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP Purge Control Valve Circuit',
      ),
      const DtcInfo(
        code: 'P0446',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP Vent Control Circuit',
      ),
      const DtcInfo(
        code: 'P0455',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP Large Leak Detected',
        remedy: 'Strange busonul; inspecteaza furtunurile EVAP pentru fisuri.',
      ),
      const DtcInfo(
        code: 'P0456',
        system: 'EVAP',
        impact: DtcImpact.low,
        description: 'EVAP Very Small Leak Detected',
      ),

      // ============================ COOLING / FANS ============================
      const DtcInfo(
        code: 'P0480',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'Cooling Fan 1 Control Circuit',
      ),
      const DtcInfo(
        code: 'P0481',
        system: 'Cooling',
        impact: DtcImpact.medium,
        description: 'Cooling Fan 2 Control Circuit',
      ),
      const DtcInfo(
        code: 'P0500',
        system: 'Speed',
        impact: DtcImpact.medium,
        description: 'Vehicle Speed Sensor Malfunction',
        remedy: 'Verifica VSS, conectorul si firele.',
      ),
      const DtcInfo(
        code: 'P0501',
        system: 'Speed',
        impact: DtcImpact.medium,
        description: 'Vehicle Speed Sensor Range/Performance',
      ),

      // ============================ IDLE / VOLTAGE ============================
      const DtcInfo(
        code: 'P0506',
        system: 'Idle',
        impact: DtcImpact.medium,
        description: 'Idle Air Control System RPM Lower Than Expected',
        remedy: 'Curata clapeta si IACV. Reset adaptari.',
      ),
      const DtcInfo(
        code: 'P0507',
        system: 'Idle',
        impact: DtcImpact.medium,
        description: 'Idle Air Control System RPM Higher Than Expected',
        remedy: 'Cauta scurgeri de vacuum si curata clapeta.',
      ),
      const DtcInfo(
        code: 'P0521',
        system: 'Oil',
        impact: DtcImpact.high,
        description: 'Engine Oil Pressure Sensor/Switch Range/Performance',
      ),
      const DtcInfo(
        code: 'P0522',
        system: 'Oil',
        impact: DtcImpact.high,
        description: 'Engine Oil Pressure Sensor Low Voltage',
      ),
      const DtcInfo(
        code: 'P0523',
        system: 'Oil',
        impact: DtcImpact.high,
        description: 'Engine Oil Pressure Sensor High Voltage',
      ),
      const DtcInfo(
        code: 'P0560',
        system: 'Power',
        impact: DtcImpact.medium,
        description: 'System Voltage Malfunction',
        remedy: 'Verifica bateria, alternatorul si masele motorului.',
      ),
      const DtcInfo(
        code: 'P0562',
        system: 'Power',
        impact: DtcImpact.medium,
        description: 'System Voltage Low',
        remedy: 'Inspecteaza bateria si alternatorul.',
      ),
      const DtcInfo(
        code: 'P0563',
        system: 'Power',
        impact: DtcImpact.medium,
        description: 'System Voltage High',
        remedy: 'Verifica regulatorul alternatorului.',
      ),

      // ============================ TRANSMISSION ============================
      const DtcInfo(
        code: 'P0700',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Transmission Control System Malfunction',
        remedy: 'Scaneaza modulul TCM cu un scanner OEM pentru subcoduri.',
      ),
      const DtcInfo(
        code: 'P0715',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Input/Turbine Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'P0720',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Output Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'P0730',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Incorrect Gear Ratio',
      ),
      const DtcInfo(
        code: 'P0740',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Torque Converter Clutch Circuit',
      ),
      const DtcInfo(
        code: 'P0741',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Torque Converter Clutch Performance/Stuck Off',
      ),
      const DtcInfo(
        code: 'P0750',
        system: 'Transmission',
        impact: DtcImpact.high,
        description: 'Shift Solenoid "A" Malfunction',
      ),

      // ============================ EMISSIONS / DIESEL ============================
      const DtcInfo(
        code: 'P2002',
        system: 'DPF',
        impact: DtcImpact.medium,
        description: 'Diesel Particulate Filter Efficiency Below Threshold',
        remedy: 'Regenerare DPF (drum lung peste 80 km/h) sau curatare profesionala.',
      ),
      const DtcInfo(
        code: 'P2032',
        system: 'DPF',
        impact: DtcImpact.medium,
        description: 'Exhaust Gas Temp Sensor Circuit Low (B1S2)',
      ),
      const DtcInfo(
        code: 'P2033',
        system: 'DPF',
        impact: DtcImpact.medium,
        description: 'Exhaust Gas Temp Sensor Circuit High (B1S2)',
      ),
      const DtcInfo(
        code: 'P2096',
        system: 'Fuel Trim',
        impact: DtcImpact.medium,
        description: 'Post Catalyst Fuel Trim System Too Lean (Bank 1)',
      ),
      const DtcInfo(
        code: 'P2097',
        system: 'Fuel Trim',
        impact: DtcImpact.medium,
        description: 'Post Catalyst Fuel Trim System Too Rich (Bank 1)',
      ),
      const DtcInfo(
        code: 'P2122',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'Throttle/Pedal Position Sensor "D" Low Input',
      ),
      const DtcInfo(
        code: 'P2127',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'Throttle/Pedal Position Sensor "E" Low Input',
      ),
      const DtcInfo(
        code: 'P2138',
        system: 'Throttle',
        impact: DtcImpact.high,
        description: 'Throttle Pedal Position Sensor "D"/"E" Voltage Correlation',
        consequence: 'Limp mode si pierdere putere.',
        remedy: 'Inlocuieste senzorul de pedala — adesea apare la peste 150.000 km.',
      ),
      const DtcInfo(
        code: 'P2270',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Signal Stuck Lean (B1S2)',
      ),
      const DtcInfo(
        code: 'P2271',
        system: 'O2 Sensors',
        impact: DtcImpact.medium,
        description: 'O2 Sensor Signal Stuck Rich (B1S2)',
      ),

      // ============================ TURBO / BOOST ============================
      const DtcInfo(
        code: 'P0234',
        system: 'Turbo',
        impact: DtcImpact.high,
        description: 'Turbocharger Overboost Condition',
        remedy: 'Verifica wastegate-ul si conductele de vacuum/boost.',
      ),
      const DtcInfo(
        code: 'P0299',
        system: 'Turbo',
        impact: DtcImpact.high,
        description: 'Turbocharger/Supercharger Underboost',
        consequence: 'Limp mode si pierdere severa de putere.',
        remedy:
            'Cauta scurgeri pe traseul de boost (intercooler, furtunuri), '
            'verifica actuatorul de geometrie variabila.',
      ),

      // ============================ COMMS / NETWORK ============================
      const DtcInfo(
        code: 'U0001',
        system: 'CAN Bus',
        impact: DtcImpact.high,
        description: 'High Speed CAN Communication Bus',
      ),
      const DtcInfo(
        code: 'U0100',
        system: 'CAN Bus',
        impact: DtcImpact.critical,
        description: 'Lost Communication With ECM/PCM "A"',
        consequence: 'Modulul motor nu raspunde — vehiculul poate fi nerulabil.',
        remedy:
            'Verifica alimentarea ECU-ului, masele si magistrala CAN H/L. '
            'Cauta sigurante arse.',
      ),
      const DtcInfo(
        code: 'U0101',
        system: 'CAN Bus',
        impact: DtcImpact.critical,
        description: 'Lost Communication With TCM',
      ),
      const DtcInfo(
        code: 'U0121',
        system: 'CAN Bus',
        impact: DtcImpact.high,
        description: 'Lost Communication With ABS Control Module',
      ),
      const DtcInfo(
        code: 'U0140',
        system: 'CAN Bus',
        impact: DtcImpact.high,
        description: 'Lost Communication With Body Control Module',
      ),
      const DtcInfo(
        code: 'U0155',
        system: 'CAN Bus',
        impact: DtcImpact.medium,
        description: 'Lost Communication With Instrument Panel Cluster',
      ),

      // ============================ CHASSIS / BRAKES ============================
      const DtcInfo(
        code: 'C0035',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'Left Front Wheel Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'C0040',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'Right Front Wheel Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'C0045',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'Left Rear Wheel Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'C0050',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'Right Rear Wheel Speed Sensor Circuit',
      ),
      const DtcInfo(
        code: 'C0110',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'ABS Pump Motor Circuit',
      ),
      const DtcInfo(
        code: 'C1201',
        system: 'ABS',
        impact: DtcImpact.high,
        description: 'Engine Control System Malfunction (ABS)',
      ),

      // ============================ BODY ============================
      const DtcInfo(
        code: 'B1318',
        system: 'Body',
        impact: DtcImpact.medium,
        description: 'Battery Voltage Low',
      ),
      const DtcInfo(
        code: 'B2477',
        system: 'Body',
        impact: DtcImpact.medium,
        description: 'Module Configuration Failure',
      ),

      // ============================ SECURITY / PARK ============================
      const DtcInfo(
        code: 'P1604',
        system: 'Security',
        impact: DtcImpact.medium,
        description: 'Startability Malfunction',
      ),
      const DtcInfo(
        code: 'P1614',
        system: 'Security',
        impact: DtcImpact.medium,
        description: 'IMMO Code/ECM Mismatch',
      ),
    ];

    return {for (final c in codes) c.code: c};
  }
}
