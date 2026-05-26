# Voltera Fleet Dashboard

Web app pentru monitorizarea flotei Voltera — telemetrie live, replay trasee, centru de alerte, analytics.

Stack: **Next.js 14** (App Router) · **TypeScript** · **Tailwind** · **MapLibre GL** · **Recharts** · **Supabase** (Auth + Realtime + Postgres).

---

## Local development

### 1. Variabile de mediu

```powershell
copy .env.local.example .env.local
```

Apoi editeaza `.env.local` cu:
- `NEXT_PUBLIC_SUPABASE_URL` — din Supabase Studio → Project Settings → API
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — `anon public` key (NU `service_role`)
- `GROQ_API_KEY` — pentru AI Copilot / Explica DTC / Insights. Cheie **gratuita** (fara card) la <https://console.groq.com/keys>. Daca lipseste, AI-ul returneaza 503 dar restul aplicatiei merge normal.

### 2. Instalare si pornire

```powershell
npm install
npm run dev
```

Aplicatia ruleaza la <http://localhost:3000>.

### 3. Creeaza un cont dispecer

Conturile se creeaza manual in Supabase Studio:

1. **Authentication → Users → Add user → Create new user**
2. Email + parola
3. Confirma `Auto Confirm User` (altfel ramane neconfirmat)

Apoi te loghezi cu acele credentiale in <http://localhost:3000/login>.

---

## Deploy pe Vercel

### Pasul 1 — push pe GitHub
Daca repo-ul nu e pe GitHub inca:

```powershell
git init
git add .
git commit -m "Voltera Fleet Dashboard v1.0"
gh repo create voltera-fleet-dashboard --private --source=. --push
```

### Pasul 2 — import in Vercel
1. <https://vercel.com/new> → importeaza repo-ul
2. **Framework Preset:** Next.js (detectat automat)
3. **Root Directory:** `voltera_fleet_dashboard` daca repo-ul e mai mare; altfel default
4. **Environment Variables** (apasa Add pentru fiecare):
   - `NEXT_PUBLIC_SUPABASE_URL` = `https://...supabase.co`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = `eyJhbGc...`
5. **Deploy** → Vercel construieste in ~2 min, primesti URL `https://voltera-fleet-dashboard-xxx.vercel.app`

### Pasul 3 — domeniu custom (optional)
**Project Settings → Domains** → adauga `voltera.example.ro`. Pune un CNAME catre `cname.vercel-dns.com` la registrar.

### Pasul 4 — adauga URL-ul Vercel in Supabase
**Authentication → URL Configuration → Site URL** = `https://voltera-fleet-dashboard-xxx.vercel.app` (sau domeniul tau).

Plus la **Redirect URLs** adauga acelasi URL. Asta previne erorile la magic links / OAuth.

---

## Structura aplicatiei

```
src/
├── app/
│   ├── layout.tsx           # HTML root
│   ├── globals.css          # Tailwind + scrollbar custom
│   ├── login/
│   │   ├── page.tsx         # Form email + parola
│   │   └── actions.ts       # Server actions (signIn/signOut)
│   └── (app)/               # Rute protejate (middleware verifica sesiunea)
│       ├── layout.tsx       # Sidebar + Topbar shell
│       ├── page.tsx         # Dashboard (harta live)
│       ├── vehicles/
│       │   ├── page.tsx     # Lista vehicule
│       │   └── [id]/page.tsx # Detalii vehicul
│       ├── drivers/page.tsx # Soferi + leaderboard
│       ├── trips/
│       │   ├── page.tsx     # Lista trasee
│       │   └── [id]/page.tsx # Replay traseu
│       ├── alerts/page.tsx  # Centru evenimente
│       ├── analytics/page.tsx # Grafice agregate
│       └── settings/page.tsx # Profil + logout
├── components/
│   ├── shell/{Sidebar,Topbar}.tsx
│   ├── ui/{PageShell,Card,StatusBadge}.tsx
│   ├── FleetMap.tsx         # MapLibre + Realtime markers
│   ├── VehicleDrawer.tsx
│   ├── AlertsTicker.tsx
│   └── TripReplayMap.tsx
├── lib/
│   ├── supabase.ts          # Client browser + tipuri
│   └── supabase/
│       ├── client.ts        # createBrowserClient
│       ├── server.ts        # createServerClient (cu cookies)
│       └── middleware.ts    # Auth guard pe fiecare request
└── middleware.ts            # Hook-uieste guard-ul global
```

---

## Configurare Supabase Realtime

Pentru ca pinii sa se miste pe harta in timp real:

**Database → Replication → supabase_realtime** → bifeaza:
- `telemetry_samples`
- `events`
- `trips`
- `vehicles`

Daca nu sunt vizibile, ruleaza in SQL Editor:
```sql
alter publication supabase_realtime add table public.telemetry_samples;
alter publication supabase_realtime add table public.events;
alter publication supabase_realtime add table public.trips;
alter publication supabase_realtime add table public.vehicles;
```

---

## Pagini & functionalitati

| Pagina | Functii |
|---|---|
| `/` Dashboard | Harta MapLibre full-screen · markeri realtime · trail pe vehicul selectat · KPI bar live · alerts inbox · search flota |
| `/vehicles` | Tabel cu inventar · filtre status · cautare · drill-down catre detalii |
| `/vehicles/[id]` | KPI live · evenimente · ultimele 10 trasee · status detaliat |
| `/drivers` | Cards per sofer · scor eco · top 3 leaderboard · cautare |
| `/trips` | Tabel cu filtre data/sofer/vehicul · replay direct |
| `/trips/[id]` | Replay harta + grafic + slider (pagina existenta) |
| `/alerts` | Lista evenimente · filtre severitate + state · butoane "rezolva" · Realtime |
| `/analytics` | Grafice Recharts: distanta zilnica, distributie alerte, top 5 eco-drivers |
| `/settings` | Profil dispecer · info Supabase · instructiuni tableta · logout |

---

## AI (Llama 3.3 70B via Groq)

Doua integrari user-invoked (zero background calls), toate prin Groq (Llama 3.3 70B, free tier 30 req/min + ~200 tok/s, fara card, fara restrictii UE). Cheia se seteaza in `.env.local` la `GROQ_API_KEY` (<https://console.groq.com/keys>).

| Feature | Unde se vede | Endpoint |
|---|---|---|
| **AI Copilot** | Buton flotant bottom-right pe orice pagina. Chat in romana cu acces la snapshot-ul flotei (vehicule, ultimele 20 evenimente, ultimele 8 trasee). | `POST /api/ai/chat` |
| **Explica DTC** | Buton "EXPLICA CU AI" sub fiecare alerta cu cod DTC (P0xxx / B0xxx / C0xxx / U0xxx) in `/alerts`. Returneaza cauze, simptome, actiuni, cost estimat. | `POST /api/ai/explain-dtc` |

Cheia e server-side (fara prefix `NEXT_PUBLIC_`), nu ajunge in browser. Tot contextul de flota e construit in `src/lib/ai/context.ts` direct din Supabase la fiecare cerere. Endpoint-ul DTC foloseste Groq JSON mode pentru raspunsuri garantat parseabile.

---

## Securitate

- Toate rutele sub `(app)/` sunt protejate de **middleware Supabase Auth**
- `anon` key e public-safe (RLS policies decid ce poate citi/scrie)
- Pentru productie: activeaza RLS strict pe toate tabelele si emite JWT-uri per tenant
- Cookies sunt HttpOnly + Secure (default `@supabase/ssr`)

---

## Demo flow (4 minute)

1. **Pe tableta** (Voltera app) → MORE → FLEET CLOUD → SALVEAZA & ACTIVEAZA → GPS LIVE
2. **Browser** → vercel URL → login cu cont dispecer
3. **Dashboard** → vezi flota live, click pe pinul tabletei
4. **MAP** → drawer cu telemetria; KPI bar cu coordonate GPS
5. **Tableta** → MORE → FLEET CLOUD → **TRIGGER DTC** → alerta rosie apare in dashboard in <1s
6. **/alerts** → vezi alerta listata, apasa **REZOLVA**
7. **/trips/[id]** → daca ai inregistrat un drum, vezi replay-ul

---

Cod scris: Mai 2026 · Pentru: ICE USV demo
