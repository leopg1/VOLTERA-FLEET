// Simulator de flota — genereaza miscare credibila pentru cele 3 masini demo
// Ruleaza: node 002_simulator.mjs
//
// Ce face: la fiecare 2s, pentru fiecare vehicul, calculeaza o noua pozitie
// pe un drum circular in jurul Sucevei + valori OBD plauzibile, apoi face
// INSERT in telemetry_samples. Util cand vrei demo fara tableta reala.

import { createClient } from '@supabase/supabase-js'
import 'dotenv/config'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Lipseste SUPABASE_URL sau SUPABASE_SERVICE_ROLE_KEY in .env')
  process.exit(1)
}

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const VEHICLES = [
  {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Ion (Honda)',
    center: { lat: 47.6519, lon: 26.2553 }, // Suceava centru
    radius: 0.012,
    phase: 0,
    speed: 35,
  },
  {
    id: '22222222-2222-2222-2222-222222222222',
    name: 'Maria (BMW)',
    center: { lat: 47.6420, lon: 26.2410 }, // Burdujeni
    radius: 0.018,
    phase: Math.PI / 2,
    speed: 55,
  },
  {
    id: '33333333-3333-3333-3333-333333333333',
    name: 'Stefan (VW)',
    center: { lat: 47.6610, lon: 26.2680 }, // Itcani
    radius: 0.009,
    phase: Math.PI,
    speed: 22,
  },
]

const TICK_MS = 2000
const SPEED_RAD_PER_TICK = 0.04 // cat de repede se misca pe cerc

let tick = 0

async function step() {
  tick++
  for (const v of VEHICLES) {
    v.phase += SPEED_RAD_PER_TICK
    const lat = v.center.lat + Math.cos(v.phase) * v.radius
    const lon = v.center.lon + Math.sin(v.phase) * v.radius

    // Variatie de viteza naturala (sin) ca sa nu fie monoton
    const speedVar = Math.sin(v.phase * 2) * 12
    const speedKmh = Math.max(0, v.speed + speedVar + (Math.random() - 0.5) * 6)

    // RPM in functie de viteza, presupunand treapta logica
    const rpm = 800 + speedKmh * 35 + Math.random() * 200

    const sample = {
      vehicle_id: v.id,
      ts: new Date().toISOString(),
      lat,
      lon,
      speed_kmh: Number(speedKmh.toFixed(1)),
      rpm: Number(rpm.toFixed(0)),
      coolant: 78 + Math.sin(tick / 30) * 8 + Math.random() * 2,
      throttle: Math.min(100, 15 + speedKmh * 0.4 + Math.random() * 10),
      engine_load: Math.min(100, 25 + speedKmh * 0.5),
      maf: 2 + speedKmh * 0.06 + Math.random(),
      battery: 14.1 + Math.random() * 0.3,
      fuel_pct: Math.max(20, 80 - tick * 0.02),
      intake_air_temp: 22 + Math.random() * 6,
    }

    const { error } = await sb.from('telemetry_samples').insert(sample)
    if (error) {
      console.error(`[${v.name}] insert err:`, error.message)
    } else {
      process.stdout.write(`✓ ${v.name.padEnd(15)} ${speedKmh.toFixed(0).padStart(3)} km/h | rpm ${rpm.toFixed(0)}\n`)
    }
  }

  // La fiecare ~30s, declanseaza un eveniment pe o masina random pentru demo
  if (tick % 15 === 0) {
    const v = VEHICLES[Math.floor(Math.random() * VEHICLES.length)]
    const dtcs = [
      { code: 'P0301', title: 'Cylinder 1 Misfire Detected', sev: 'warning' },
      { code: 'P0171', title: 'Fuel System Too Lean (Bank 1)', sev: 'warning' },
      { code: 'P0455', title: 'EVAP System Large Leak Detected', sev: 'info' },
    ]
    const dtc = dtcs[Math.floor(Math.random() * dtcs.length)]
    await sb.from('events').insert({
      vehicle_id: v.id,
      type: 'dtc',
      severity: dtc.sev,
      code: dtc.code,
      title: dtc.title,
      description: 'Detectat automat de simulator (demo).',
    })
    console.log(`  ⚠  Event nou pe ${v.name}: ${dtc.code}`)
  }
}

console.log('Simulator pornit. CTRL+C pentru oprire.\n')
setInterval(step, TICK_MS)
