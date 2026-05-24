/// OBD-II protocol identifiers (matching ELM327 ATSP commands).
enum ObdProtocol {
  auto(0, 'Automatic'),
  saeJ1850Pwm(1, 'SAE J1850 PWM (41.6 kbps)'),
  saeJ1850Vpw(2, 'SAE J1850 VPW (10.4 kbps)'),
  iso9141_2(3, 'ISO 9141-2 (5 baud init)'),
  iso14230_4Kwp5Baud(4, 'ISO 14230-4 KWP (5 baud init)'),
  iso14230_4KwpFast(5, 'ISO 14230-4 KWP (fast init)'),
  iso15765_4Can11Bit500K(6, 'ISO 15765-4 CAN (11-bit, 500 kbps)'),
  iso15765_4Can29Bit500K(7, 'ISO 15765-4 CAN (29-bit, 500 kbps)'),
  iso15765_4Can11Bit250K(8, 'ISO 15765-4 CAN (11-bit, 250 kbps)'),
  iso15765_4Can29Bit250K(9, 'ISO 15765-4 CAN (29-bit, 250 kbps)'),
  saeJ1939Can(10, 'SAE J1939 CAN (29-bit, 250 kbps)');

  final int id;
  final String label;
  const ObdProtocol(this.id, this.label);

  String get atCommand => 'ATSP$id';
}

/// OBD-II diagnostic services (modes).
enum ObdMode {
  liveData(0x01, 'Show current data'),
  freezeFrame(0x02, 'Freeze frame data'),
  storedDtc(0x03, 'Stored DTCs'),
  clearDtc(0x04, 'Clear DTCs'),
  o2Sensor(0x05, 'O2 sensor monitoring'),
  monitorTest(0x06, 'On-board monitoring test results'),
  pendingDtc(0x07, 'Pending DTCs'),
  controlTest(0x08, 'Control of on-board systems'),
  vehicleInfo(0x09, 'Vehicle information (VIN)'),
  permanentDtc(0x0A, 'Permanent DTCs');

  final int code;
  final String description;
  const ObdMode(this.code, this.description);

  String get hex => code.toRadixString(16).padLeft(2, '0').toUpperCase();
}
