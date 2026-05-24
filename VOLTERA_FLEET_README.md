
# Voltera Fleet — pornire end-to-end (demo ICE USV)

Sistem de monitorizare flota construit pe app-ul existent `obd_droid_flutter`.
Trei piese:

```
obd_droid_flutter/        ← app Flutter pe tableta (CloudSync activ)
voltera_fleet_backend/    ← migrari SQL Supabase + simulator de demo
voltera_fleet_dashboard/  ← Next.js + MapLibre, web dashboard pentru dispecer
```

Tot setup-ul dureaza **~45 minute** prima data. Dupa, rulezi cu 3 comenzi.

---

## Pas 1 — Supabase project (5 min)

1. Mergi pe https://supabase.com → **New Project**
2. Nume: `voltera-fleet-demo`, regiune: `eu-central` (Frankfurt — cel mai aproape de SV)
3. Asteapta ~2 min sa se provisioneze
4. **Project Settings → API** → noteaza-ti:
   - `Project URL` (ex. `https://abcd.supabase.co`)
   - `anon public key` (key-ul de jos, NU service_role)
   - `service_role key` (doar pentru simulator backend)

## Pas 2 — Schema + seed (3 min)

1. In Supabase Studio → **SQL Editor → New query**
2. Copy-paste **tot** continutul din `voltera_fleet_backend/migrations/001_init_schema.sql` → **Run**
3. Daca primesti eroare la `alter publication ... add table` (poate exista deja un publication preset), ignora — il setezi manual la Pas 3.
4. Query nou → copy-paste `voltera_fleet_backend/seed/001_demo_fleet.sql` → **Run**
   - Asta creeaza 3 vehicule demo + 1 DTC stocat pe BMW.

## Pas 3 — Verifica Realtime (1 min)

In Supabase Studio: **Database → Replication → supabase_realtime** → asigura-te ca sunt bifate:
- `telemetry_samples`
- `events`
- `vehicles`

Daca lipsesc, click **Add** si selecteaza.

## Pas 4 — Dashboard web (15 min)

```powershell
cd "voltera_fleet_dashboard"
copy .env.local.example .env.local
# editeaza .env.local cu URL-ul si anon key-ul tau

npm install
npm run dev
```

Deschide http://localhost:3000 — vezi 3 markere fixe pe harta Sucevei (fara miscare inca).

## Pas 5 — Simulator de flota (3 min)

In **alta consola**:
```powershell
cd "voltera_fleet_backend/seed"
copy .env.example .env
# editeaza .env: pune URL si SERVICE_ROLE_KEY (nu anon!)

npm install
npm run simulator
```

Vei vedea output-ul:
```
✓ Ion (Honda)      42 km/h | rpm 2245
✓ Maria (BMW)      54 km/h | rpm 2843
✓ Stefan (VW)      21 km/h | rpm 1535
  ⚠  Event nou pe Ion (Honda): P0301
```

In dashboard (deja deschis), **markerele incep sa se miste** in cerc in jurul Sucevei. La fiecare ~30s apare o alerta noua in inbox-ul jos stanga.

**Aceasta e poza demo de baza. De aici incolo, totul e bonus.**

## Pas 6 — Conecteaza tableta cu app-ul Flutter (10 min)

Pe tableta (sau emulator):
```powershell
cd "obd_droid_flutter"
flutter pub get
flutter run
```

In app:
1. Tap pe **MORE** (bottom nav)
2. Tap pe tile-ul **FLEET CLOUD** (verde)
3. Completeaza:
   - **Supabase URL** = URL-ul tau
   - **Anon Key** = anon public key
   - **Vehicle ID** = `11111111-1111-1111-1111-111111111111` (Honda Ion)
4. Tap **SALVEAZA & ACTIVEAZA**
5. Status-ul devine **CLOUD ACTIV**

Acum:
- Conecteaza la **Mock Vehicle** (Connect screen) sau adaptorul ESP32 real
- Live data polling incepe → sample-urile se urca in Supabase la fiecare 3s
- In dashboard web, masina "Honda Ion" primeste date noi peste cele de la simulator

**Trigger demo DTC:**
- In **FLEET CLOUD** screen, tap **TRIGGER DTC (P0420)**
- In dashboard, in 1-2s apare alerta rosie in inbox jos stanga

**Trip replay:**
- In app, mergi pe **TRIP ANALYSIS** (MORE → TRIP ANALYSIS) si apasa **START TRIP**
- Lasa 30s sa colecteze date, apoi **STOP TRIP**
- In dashboard, click masina → drawer dreapta → vezi trip-ul in lista → click **REPLAY**
- Pe ecranul de replay: harta + grafic + slider sincronizat

---

## Scriptul prezentarii (4 minute)

| Min | Ecran | Ce zici |
|-----|-------|---------|
| 0:00 | Tableta — Dashboard app | "Aici e dispozitivul din masina. Citeste OBD-II prin ESP32 WiFi." |
| 0:30 | Tableta — Live Data | "20 PID-uri standard SAE J1979, frecventa 5 Hz." |
| 1:00 | Laptop — `localhost:3000` | "Dashboard-ul web. 3 vehicule pilot in Suceava." |
| 1:30 | Laptop — click pe vehicul | "Telemetrie live, status, eventuri OBD, istoric trasee." |
| 2:00 | Tableta — FLEET CLOUD → TRIGGER DTC | "Simulez un cod de eroare detectat de ECU." |
| 2:05 | Laptop — alerta apare | "1-2 secunde latenta E2E. Tot prin Supabase Realtime." |
| 2:30 | Laptop — REPLAY pe un trip | "Trip Replay: harta + grafic sincronizat cu slider de timp." |
| 3:30 | Slide arhitectura | "Flutter → Supabase Postgres + PostGIS + Realtime → Next.js + MapLibre." |
| 4:00 | Q&A | |

---

## Arhitectura (pentru slide-uri)

```
┌─────────────────────────────┐
│ TABLETA IN MASINA           │
│ ┌─────────────────────────┐ │
│ │ Voltera Driver (Flutter)│ │
│ │  ├─ ELM327 client       │ │
│ │  ├─ 20 PID polling      │ │
│ │  ├─ DTC scan            │ │
│ │  └─ CloudSync ──────────┼─┼──→ HTTPS batch /3s
│ └─────────────────────────┘ │
│   ↑ WiFi                    │
│   ESP32 ─→ OBD-II port      │
└─────────────────────────────┘
                              ↓
┌─────────────────────────────────────────┐
│ SUPABASE (Frankfurt)                    │
│  ├─ Postgres + PostGIS                  │
│  ├─ Tables: vehicles, telemetry_samples,│
│  │          trips, events               │
│  ├─ View: fleet_status (last per car)   │
│  ├─ RLS policies                        │
│  └─ Realtime publication                │
└─────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────┐
│ DISPECER LAPTOP / TABLET                │
│  Voltera Fleet Dashboard (Next.js)      │
│   ├─ MapLibre + OpenFreeMap tiles       │
│   ├─ Live markers (polling 4s)          │
│   ├─ Realtime alerts subscription       │
│   ├─ Vehicle drawer + telemetry         │
│   └─ Trip Replay (map + chart + slider) │
└─────────────────────────────────────────┘
```

---

## Stack tehnic

| Layer | Tehnologie | De ce |
|---|---|---|
| In-vehicle | Flutter 3.19 + Dart 3.3 | Cross-platform, hot reload, exista deja |
| Cloud sync | `supabase_flutter` 2.5 | Auth + Realtime + storage intr-un singur SDK |
| Backend | Supabase managed | Postgres + PostGIS + Realtime + Auth out of the box |
| Geospatial | PostGIS extension | Geo queries, viitoare geofences |
| Dashboard | Next.js 14 + App Router | SSR, routing rapid, ecosistem matur |
| Harta | MapLibre GL + OpenFreeMap | Open-source, 0 costuri, fara API key |
| Charts | Recharts | Simplu, React-native, suficient pentru demo |
| Styling | Tailwind 3 | Iteratii vizuale rapide |

---

## Gotchas care te pot bloca la demo

1. **Tableta pe WiFi-ul ESP32 NU are net** → CloudSync nu trimite. Pentru demo, foloseste **Mock mode** sau pune tableta pe WiFi normal cu hotspot telefonul.
2. **anon key expune scriere** → ai pus RLS permisiv pentru demo. **NU lasa demo-ul live pe internet** — oricine poate scrie. Pentru productie, JWT per device.
3. **OpenFreeMap tiles** sunt comunitare → uneori sunt lente. Pentru prezentare, lasa tabul deschis 10 min inainte ca tile-urile sa fie cache-uite.
4. **Realtime in dashboard** are nevoie de WebSocket → daca esti pe WiFi-ul USV cu firewall agresiv, foloseste hotspot 4G.
5. **Daca pica simulatorul** in timpul prezentarii → markerii raman pe loc dupa 2 min status `offline`. Re-ruleaza `npm run simulator`.

---

## Ce poti adauga dupa demo

- **GPS real** in app (`geolocator` plugin) — coordonate vin din tableta, nu fictive
- **Geofences** — `ST_Within` query pe PostGIS, alert la intrare/iesire zona
- **Cost analytics** — pret combustibil x consum mediu pe sofer
- **Driver scorecards** — clasament eco/safety lunar
- **Push notifications** — FCM cand apare DTC critical
- **Multi-tenant** — adauga `tenant_id` la toate tabelele si activeaza RLS strict

---

## Troubleshooting rapid

| Simptom | Cauza probabila | Fix |
|---|---|---|
| Dashboard: "Niciun vehicul" | Seed-ul SQL nu s-a rulat | Ruleaza `001_demo_fleet.sql` |
| Markeri nu se misca | Simulator oprit | `npm run simulator` |
| Flutter: build error supabase_flutter | Cache stricat | `flutter clean && flutter pub get` |
| Realtime nu primeste evenimente | Replication nu e activat | Vezi Pas 3 |
| Map e gri / nu se incarca | OpenFreeMap pica | Schimba style URL in `FleetMap.tsx` cu `maptiler` |
| `RLS error: new row violates policy` | Lipsesc policies | Re-ruleaza migration-ul, sectiunea RLS |

---

Cod scris: Mai 2026 · Pentru: prezentare ICE USV
