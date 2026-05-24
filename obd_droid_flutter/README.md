# OBD-Droid (Flutter)

Port complet **Flutter / Dart** al aplicatiei [OBD-Droid](https://github.com/Wal33D/OBD-Droid).
Rezultatul: aceeasi suita profesionala de diagnoza OBD-II, dar acum *cross-platform* (Android + iOS dintr-un singur cod), cu UI nou si modern.

> **TL;DR**
> 1. Instaleaza Flutter (5 minute).
> 2. Activeaza USB Debugging pe Lenovo Tab M11.
> 3. `flutter pub get && flutter run` → aplicatia ruleaza pe tableta.

---

## Cum se compara cu originalul

| Aspect              | OBD-Droid (Java)        | OBD-Droid Flutter (acest proiect)              |
| ------------------- | ----------------------- | ---------------------------------------------- |
| Limba               | Java                    | Dart                                           |
| Arhitectura         | Activities + Services   | Provider + servicii curate, async-first        |
| UI                  | XML / Material 2        | Material 3 + tema personalizata "automotive"   |
| Live Data           | RecyclerView + speedview| `MetricCard` + grafice `fl_chart` + gauge propriu|
| Bluetooth           | Classic SPP             | BLE (`flutter_blue_plus`) + Mock pentru demo  |
| USB                 | usb-serial-for-android  | `usb_serial`                                   |
| AI                  | OpenAI                  | OpenAI (acelasi API)                           |
| Recalls             | NHTSA                   | NHTSA                                          |
| Platforme           | Doar Android            | Android + iOS dintr-un singur build            |

---

## Arhitectura

```
lib/
├── core/
│   ├── connection/        # ObdTransport (Bluetooth, USB, Mock, WiFi)
│   ├── obd/               # ElmEngine, ObdService, PidCatalog
│   ├── models/            # Pid, Dtc, Vehicle, ConnectionState, ObdProtocol
│   └── services/          # NhtsaService, CoPilotService, CsvLogger, LocationService
├── providers/             # State management (Provider / ChangeNotifier)
├── features/
│   ├── connect/           # Selectie adaptor + scan BLE/USB
│   ├── dashboard/         # Ecran principal cu gauge-uri + actiuni
│   ├── live_data/         # PID grid + grafice
│   ├── fault_codes/       # DTC scan + clear
│   ├── scan/              # Full vehicle scan
│   ├── vehicle_info/      # Decode VIN
│   ├── recalls/           # Campanii NHTSA
│   ├── copilot/           # Chat OpenAI
│   ├── settings/          # Tema, refresh, API key
│   └── track_mode/        # (placeholder pentru module viitoare)
├── widgets/               # MetricCard, PrimaryGauge, StatusPill
├── theme/                 # AppTheme.dark/light
├── app_shell.dart         # Navigation
└── main.dart
```

---

## Instalare Flutter (~5 minute)

### 1. Descarca Flutter
- Mergi la **<https://docs.flutter.dev/get-started/install/windows>**
- Descarca **flutter_windows_*.zip** (~1 GB)
- Extrage in `C:\flutter` (NU in `Program Files`!)

### 2. Adauga Flutter in PATH
```powershell
[System.Environment]::SetEnvironmentVariable(
  "Path", $env:Path + ";C:\flutter\bin", "User"
)
```
Inchide si redeschide PowerShell.

### 3. Verifica
```powershell
flutter --version
flutter doctor
```

`flutter doctor` iti spune ce mai trebuie: in cazul tau probabil iti va cere
**Android Command Line Tools** si **JDK 17** (pe care deja le ai).

### 4. Accepta licentele Android
```powershell
flutter doctor --android-licenses
```

---

## USB Debugging pe Lenovo Tab M11

1. **Setari** → **Despre tableta** → apasa de **7 ori** pe **Numarul de build**.
2. Inapoi la **Setari** → **Optiuni pentru dezvoltatori** → activeaza **Depanare USB**.
3. Conecteaza tableta cu cablul USB-C la laptop.
4. Pe tableta, accepta popup-ul **"Permite depanarea USB?"** → bifeaza
   **Permite intotdeauna de pe acest computer**.
5. Verifica:
   ```powershell
   flutter devices
   ```
   Trebuie sa apara `Lenovo TB-... (mobile)`.

---

## Build & Run

In folderul proiectului:

```powershell
cd "C:\Users\leona\OneDrive\Desktop\03_PROIECTE_TECH\ICE USV CANBUS\obd_droid_flutter"

# Descarca toate dependintele (~1 minut)
flutter pub get

# Ruleaza pe tableta (auto-rebuild la salvare = hot reload)
flutter run
```

Pentru a genera un APK pe care-l poti distribui:
```powershell
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## Functii implementate

- [x] Conectare la ELM327 prin BLE / USB / mod demo
- [x] Detectie automata adaptori OBD (filtru USB pe FTDI/CH340/CP210x)
- [x] Initializare ELM327 (ATZ, ATE0, ATL0, ATSP0, ATAT1, ATH0)
- [x] Negociere automata protocol (CAN / J1850 / KWP / ISO9141)
- [x] Polling live PID-uri (RPM, viteza, temperatura, MAF, baterie etc.)
- [x] Read/clear DTC (Mode 03, 07, 0A, 04)
- [x] Decode VIN local + via NHTSA
- [x] Recalls NHTSA pentru VIN
- [x] CoPilot AI (OpenAI Chat Completions, context-aware)
- [x] Settings (refresh rate, tema, unitati, API key)
- [x] CSV logger cu GPS + accelerometru (foundation)
- [x] Theme automotive Material 3, dark mode

## Pe roadmap

- [ ] Foreground service pentru CSV logging (Android)
- [ ] Track mode (lap timer, harta GPS, accelerometre)
- [ ] iOS build (ar trebui sa mearga out-of-the-box, n-am testat)
- [ ] Migrare Bluetooth Classic (SPP) — necesita plugin nativ separat
- [ ] Salvare baseline scans + comparatie

---

## Crediti

Logica OBD si feature set inspirate din proiectul original
[Wal33D/OBD-Droid](https://github.com/Wal33D/OBD-Droid) (MIT license).
Acest port este de asemenea sub MIT.
