/**
 * Mock Fleet Simulator
 *
 * Singleton care ruleaza in browser, simuleaza 5 vehicule plimbandu-se pe rute
 * predefinite in Suceava, emite telemetrie coerenta (speed-RPM-throttle-fuel
 * legate fizic) si declanseaza evenimente ambient + manuale.
 *
 * Lifecycle:
 * - Pornit lazy la prima conexiune la mockClient (sau prin start() manual)
 * - Tick la 4 Hz (250ms) — fiecare tick avanseaza pozitia + actualizeaza
 *   telemetria + decide daca lanseaza event ambient
 * - State complet in memorie (zero persistenta)
 *
 * Eventuri externe (UI poate trigger):
 * - triggerDtc(vehicleId, code)
 * - triggerLowBattery(vehicleId)
 * - setPaused(bool), setSpeedMultiplier(1|2|5)
 */

import { ROUTES, interpolateRoute } from './routes'
import type {
  FleetStatusRow,
  FleetEvent,
  TelemetrySample,
  Trip,
} from '../supabase'

// ============ TIPURI ============

export type VehicleState = {
  id: string
  plate: string
  vin: string
  make: string
  model: string
  year: number
  color: string
  driver_name: string
  /** Ruta urmata (cheie in ROUTES). */
  route_id: string
  /** Pozitie pe ruta in km (cumulativ; modulo lungime ruta = pozitie efectiva). */
  km_along: number
  /** Personalitate: factor aplicat la viteza tinta (1.0 = normal). */
  speed_factor: number
  /** Viteza tinta curenta (km/h, smoothed). */
  target_speed_kmh: number
  /** Viteza efectiva (km/h). */
  speed_kmh: number
  /** Heading (grade 0-360). */
  heading: number
  /** Pozitie curenta. */
  lat: number
  lon: number
  /** Telemetrie. */
  rpm: number
  throttle: number
  engine_load: number
  coolant: number
  battery: number
  fuel_pct: number
  maf: number
  intake_air_temp: number
  /** Status derivat. */
  status: 'driving' | 'idle' | 'alert' | 'offline'
  /** Ultim sample timestamp. */
  last_seen_at: string
  /** Trip activ (daca exista). */
  active_trip_id: string | null
  /** Log de traseu: lista de [lon, lat] prin care a trecut.
   *  Sparsificat (puncte la min ~3m diferenta). Capat la 1500 puncte. */
  trail: Array<[number, number]>
}

type Personality = {
  baseSpeed: number // km/h tinta
  variance: number // amplitudinea oscilatiei
  aggression: number // 0-1, cat de brusc accelereaza/franeaza
  idleProbability: number // 0-1, sansa sa se opreasca la "intersectii"
}

const VEHICLES_INIT: Array<{
  vehicle: Omit<
    VehicleState,
    | 'km_along'
    | 'target_speed_kmh'
    | 'speed_kmh'
    | 'heading'
    | 'lat'
    | 'lon'
    | 'rpm'
    | 'throttle'
    | 'engine_load'
    | 'coolant'
    | 'battery'
    | 'fuel_pct'
    | 'maf'
    | 'intake_air_temp'
    | 'status'
    | 'last_seen_at'
    | 'active_trip_id'
    | 'trail'
  >
  personality: Personality
}> = [
  {
    vehicle: {
      id: '11111111-1111-1111-1111-111111111111',
      plate: 'SV-01-VLT',
      vin: '1HGCM82633A004352',
      make: 'Honda',
      model: 'Civic',
      year: 2018,
      // Trail color: cyan electric — Ion in centru
      color: '#22d3ee',
      driver_name: 'Ion Popescu',
      route_id: 'centru',
      speed_factor: 1.0,
    },
    personality: {
      baseSpeed: 35,
      variance: 8,
      aggression: 0.3,
      idleProbability: 0.04,
    },
  },
  {
    vehicle: {
      id: '22222222-2222-2222-2222-222222222222',
      plate: 'SV-07-BMW',
      vin: 'WBA8E3C50JA000001',
      make: 'BMW',
      model: '320d',
      year: 2020,
      // Trail color: violet — Maria nord-est
      color: '#a78bfa',
      driver_name: 'Maria Ionescu',
      route_id: 'nord-est',
      speed_factor: 1.3,
    },
    personality: {
      baseSpeed: 48,
      variance: 14,
      aggression: 0.7,
      idleProbability: 0.02,
    },
  },
  {
    vehicle: {
      id: '33333333-3333-3333-3333-333333333333',
      plate: 'SV-15-VWG',
      vin: 'WVWZZZ1KZ6W000123',
      make: 'Volkswagen',
      model: 'Golf VII',
      year: 2016,
      // Trail color: orange — Stefan spre gara
      color: '#fb923c',
      driver_name: 'Stefan Dumitru',
      route_id: 'gara',
      speed_factor: 0.85,
    },
    personality: {
      baseSpeed: 42,
      variance: 5,
      aggression: 0.2,
      idleProbability: 0.05,
    },
  },
  // ============ DEVICE-UL TAU CONECTAT (live OBD-II) ============
  {
    vehicle: {
      id: '00000000-0000-0000-0000-000000000099',
      plate: 'SV-99-DEV',
      vin: '1HGCM82633A999999',
      make: 'Honda',
      model: 'Civic (Device Live)',
      year: 2018,
      // Trail color: alb — ies in evidenta
      color: '#f8fafc',
      driver_name: 'EU · Device OBD-II',
      route_id: 'est-industrial',
      speed_factor: 1.0,
    },
    personality: {
      baseSpeed: 38,
      variance: 6,
      aggression: 0.3,
      idleProbability: 0.04,
    },
  },
  // ============ CAMIOANE INTERNATIONALE ============
  {
    vehicle: {
      id: '66666666-6666-6666-6666-666666666666',
      plate: 'M-VLT 2024',
      vin: 'WDB9633231L823456',
      make: 'Mercedes-Benz',
      model: 'Actros 1845 LS',
      year: 2021,
      // Trail color: red Mercedes
      color: '#ef4444',
      driver_name: 'Hans Müller',
      route_id: 'munich',
      speed_factor: 1.0,
    },
    personality: {
      baseSpeed: 55,
      variance: 6,
      aggression: 0.3,
      idleProbability: 0.07,
    },
  },
  {
    vehicle: {
      id: '77777777-7777-7777-7777-777777777777',
      plate: 'AB-456-CD',
      vin: 'VF6480000WC123456',
      make: 'Renault',
      model: 'T 480 High',
      year: 2022,
      // Trail color: green Renault
      color: '#16a34a',
      driver_name: 'Pierre Dubois',
      route_id: 'lyon',
      speed_factor: 0.95,
    },
    personality: {
      baseSpeed: 50,
      variance: 8,
      aggression: 0.35,
      idleProbability: 0.06,
    },
  },
]

// ============ EVENT BUS ============

type Listener<T> = (payload: T) => void

class EventBus<T> {
  private listeners: Set<Listener<T>> = new Set()
  subscribe(fn: Listener<T>) {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)
  }
  emit(payload: T) {
    this.listeners.forEach((fn) => fn(payload))
  }
}

export const telemetryBus = new EventBus<{ new: TelemetrySample }>()
export const eventsBus = new EventBus<{ new: FleetEvent }>()
export const stateBus = new EventBus<{ vehicles: VehicleState[] }>()

// ============ STATE GLOBAL ============

/** UUID-ul vehiculului care reprezinta TABLETA REALA conectata prin OBD-II.
 *  Cand soseste telemetrie din Supabase pe acest UUID, simulatorul cedeaza
 *  controlul si datele reale autoritare. */
export const REAL_DEVICE_VEHICLE_ID = '00000000-0000-0000-0000-000000000099'

/** Timestamp (ms) ultimului sample REAL primit per vehicul. */
const lastRealUpdate: Record<string, number> = {}
/** Sub aceste milisecunde de la ultimul update real, simulatorul NU avanseaza.
 *  Setat la 5 minute — daca tableta sta parcata sau trimite rar, vehiculul
 *  ramane unde a fost vazut ultima oara, NU sare pe ruta sintetica. */
const REAL_AUTHORITATIVE_WINDOW_MS = 300_000

const vehicles: VehicleState[] = []
const personalities = new Map<string, Personality>()
const recentEvents: FleetEvent[] = []
const trips: Trip[] = []
/** Sample sintetice per trip — folosit de Trip Replay. */
const tripSamplesMap = new Map<string, TelemetrySample[]>()

// ---- Ghost vehicles: trafic ambient anonim ca orasul sa para viu ----
type Ghost = {
  id: string
  route_id: string
  km_along: number
  speed_kmh: number
}
const ghosts: Ghost[] = []
const NUM_GHOSTS = 18
const GHOST_ROUTE_IDS = [
  'centru',
  'nord-est',
  'gara',
  'est-industrial',
  'vest-autostrada',
] as const

let started = false
let paused = false
let speedMultiplier = 1
let intervalId: number | null = null
let nextAmbientAt = 0
let sampleSeq = 0

// ============ EVENT DETECTION STATE ============
// Per-vehicul: track ultimul sample + cooldowns pentru evenimente repetate.

type EventState = {
  prevSpeed: number
  prevFuel: number
  prevBattery: number
  prevTimestamp: number
  speedZeroSinceMs: number | null
  lastEmittedAt: Record<string, number>
}

const eventStateByVehicle = new Map<string, EventState>()

// Cooldown (ms) per tip event — previne spamul cand conditia persista
const EVENT_COOLDOWN_MS: Record<string, number> = {
  harsh_brake: 6_000,
  harsh_accel: 6_000,
  speeding: 45_000,
  idle_long: 180_000,
  low_fuel: 120_000,
  low_battery: 120_000,
  overheat_mild: 60_000,
  redline: 20_000,
}

// Praguri detectie
const THRESHOLDS = {
  harshBrakeMs2: 3.5, // m/s² deceleratie
  harshAccelMs2: 3.5, // m/s² acceleratie
  speedingKmh: 70, // km/h pentru zone urbane Suceava
  truckSpeedingKmh: 90, // camion pe autostrada
  idleSecMs: 120_000, // 2 min idle
  lowFuelPct: 20,
  lowBatteryV: 11.5,
  overheatC: 105,
  redlineRpm: 5500,
}

// ============ INIT ============

function init() {
  vehicles.length = 0
  for (const { vehicle, personality } of VEHICLES_INIT) {
    const route = ROUTES[vehicle.route_id]
    const startKm = Math.random() * route.totalKm
    const { lon, lat, heading } = interpolateRoute(route, startKm)
    personalities.set(vehicle.id, personality)
    vehicles.push({
      ...vehicle,
      km_along: startKm,
      target_speed_kmh: personality.baseSpeed,
      speed_kmh: personality.baseSpeed,
      heading,
      lat,
      lon,
      rpm: 850,
      throttle: 25,
      engine_load: 30,
      coolant: 70 + Math.random() * 15,
      battery: 13.8 + Math.random() * 0.6,
      fuel_pct: 60 + Math.random() * 30,
      maf: 5 + Math.random() * 5,
      intake_air_temp: 18 + Math.random() * 8,
      status: 'driving',
      last_seen_at: new Date().toISOString(),
      active_trip_id: null,
      trail: [[lon, lat]],
    })
  }
  // Un trip "active" demonstrativ pe primul vehicul
  if (vehicles.length > 0) {
    const tripId = randomUuid()
    vehicles[0].active_trip_id = tripId
    trips.push({
      id: tripId,
      vehicle_id: vehicles[0].id,
      driver_name: vehicles[0].driver_name,
      started_at: new Date(Date.now() - 35 * 60_000).toISOString(),
      ended_at: null,
      distance_km: 22.4,
      fuel_l: 1.6,
      max_speed_kmh: 67,
      max_rpm: 3850,
      eco_score: 78,
    })
  }
  // Pre-seedez cateva trip-uri istorice per vehicul + sample-uri pentru replay
  tripSamplesMap.clear()
  for (const v of vehicles) {
    for (let i = 1; i <= 3; i++) {
      const tripId = randomUuid()
      const startedAt = new Date(
        Date.now() - i * 86_400_000 - 7_200_000,
      ).toISOString()
      const endedAt = new Date(
        Date.now() - i * 86_400_000 - 3_600_000,
      ).toISOString()
      const distanceKm = 15 + Math.random() * 25
      const maxSpeed = 50 + Math.random() * 50
      const maxRpm = 2500 + Math.random() * 2000
      trips.push({
        id: tripId,
        vehicle_id: v.id,
        driver_name: v.driver_name,
        started_at: startedAt,
        ended_at: endedAt,
        distance_km: distanceKm,
        fuel_l: 0.8 + Math.random() * 2.5,
        max_speed_kmh: maxSpeed,
        max_rpm: maxRpm,
        eco_score: Math.round(60 + Math.random() * 35),
      })
      // Genereaza samples sintetice de-a lungul rutei vehiculului
      tripSamplesMap.set(
        tripId,
        generateTripSamples(v, tripId, startedAt, endedAt, distanceKm, maxSpeed, maxRpm),
      )
    }
  }
  nextAmbientAt = Date.now() + 12_000 + Math.random() * 25_000

  // Init ghosts — 18 vehicule anonime pe rutele Sucevei
  ghosts.length = 0
  for (let i = 0; i < NUM_GHOSTS; i++) {
    const route_id = GHOST_ROUTE_IDS[i % GHOST_ROUTE_IDS.length]
    const route = ROUTES[route_id]
    if (!route) continue
    ghosts.push({
      id: `ghost-${i}`,
      route_id,
      km_along: Math.random() * route.totalKm,
      speed_kmh: 22 + Math.random() * 38,
    })
  }
}

// ============ TICK ============

const TICK_MS = 250
const DT_BASE_HOURS = TICK_MS / 1000 / 3600

function tick() {
  if (paused) return
  const dtH = DT_BASE_HOURS * speedMultiplier
  const now = new Date()

  for (const v of vehicles) {
    if (v.status === 'offline') continue
    // Daca avem date REALE recente pentru acest vehicul, simulatorul NU avanseaza
    const lastReal = lastRealUpdate[v.id]
    if (lastReal && Date.now() - lastReal < REAL_AUTHORITATIVE_WINDOW_MS) {
      continue
    }
    const p = personalities.get(v.id)!
    const route = ROUTES[v.route_id]

    // Decizie viteza tinta: oscilatie din baza + variance, plus idle ocazional
    if (Math.random() < p.idleProbability * 0.04) {
      // intra in idle 2-6s
      v.target_speed_kmh = 0
    } else if (v.target_speed_kmh === 0 && Math.random() < 0.05) {
      v.target_speed_kmh = p.baseSpeed * v.speed_factor
    } else if (Math.random() < 0.08) {
      // mica variatie
      const delta = (Math.random() * 2 - 1) * p.variance
      v.target_speed_kmh = Math.max(
        0,
        p.baseSpeed * v.speed_factor + delta,
      )
    }

    // Smooth viteza catre target (aggression controleaza rate)
    const speedDelta = v.target_speed_kmh - v.speed_kmh
    const rate = 0.08 + p.aggression * 0.18
    v.speed_kmh = Math.max(0, v.speed_kmh + speedDelta * rate)

    // Status: driving / idle (alert e setat extern de event)
    if (v.status !== 'alert') {
      v.status = v.speed_kmh > 3 ? 'driving' : 'idle'
    }

    // Avansare pe ruta (km)
    const dKm = v.speed_kmh * dtH
    v.km_along += dKm

    // Pozitie + heading din ruta
    const pos = interpolateRoute(route, v.km_along)
    v.lat = pos.lat
    v.lon = pos.lon
    v.heading = pos.heading

    // RPM coerent: idle 850, sau rpm = 800 + speed * factor + variatie
    if (v.speed_kmh < 2) {
      v.rpm = 800 + Math.random() * 100
    } else {
      // gear-ratio simulat: speed/RPM scade dupa treapta
      const gear = Math.min(6, Math.max(1, Math.floor(v.speed_kmh / 15) + 1))
      const rpmPerKmh = 75 - gear * 7 // gear 1: 68, gear 6: 33
      v.rpm = 900 + v.speed_kmh * rpmPerKmh * (0.9 + Math.random() * 0.2)
    }
    v.rpm = Math.min(6500, Math.max(750, v.rpm))

    // Throttle: 5-15 idle, scaleaza cu accelerare
    const accelerating = speedDelta > 2
    if (v.speed_kmh < 2) {
      v.throttle = 5 + Math.random() * 5
    } else if (accelerating) {
      v.throttle = 25 + p.aggression * 45 + Math.random() * 10
    } else {
      v.throttle = 12 + (v.speed_kmh / 80) * 25 + Math.random() * 8
    }
    v.throttle = Math.min(100, v.throttle)

    // Engine load similar cu throttle dar mai stabil
    v.engine_load = 0.7 * v.engine_load + 0.3 * (v.throttle * 0.85)

    // MAF: scaleaza cu RPM + throttle
    v.maf = 2 + (v.rpm / 6500) * 25 + (v.throttle / 100) * 8

    // Coolant: stabilizeaza in jur de 88-94°C cand merge
    if (v.speed_kmh > 5) {
      v.coolant = 0.985 * v.coolant + 0.015 * (88 + Math.random() * 6)
    } else {
      // idle, scade incet
      v.coolant = 0.998 * v.coolant + 0.002 * 82
    }

    // Battery: oscilatie mica in jur de 13.9-14.4
    v.battery = 0.95 * v.battery + 0.05 * (13.9 + Math.random() * 0.5)

    // Fuel: consumat proportional cu throttle (foarte mic)
    v.fuel_pct = Math.max(0, v.fuel_pct - dtH * (5 + v.throttle * 0.5))

    // Intake temp: variatie mica
    v.intake_air_temp =
      0.97 * v.intake_air_temp + 0.03 * (15 + Math.random() * 20)

    v.last_seen_at = now.toISOString()

    // Logheaza in trail daca s-a deplasat suficient (~3m la lat 47 ≈ 3e-5 deg)
    const lastTrail = v.trail[v.trail.length - 1]
    if (
      !lastTrail ||
      Math.abs(v.lat - lastTrail[1]) > 3e-5 ||
      Math.abs(v.lon - lastTrail[0]) > 3e-5
    ) {
      v.trail.push([v.lon, v.lat])
      if (v.trail.length > 1500) v.trail.shift()
    }

    // Emit telemetry sample
    sampleSeq++
    const sample: TelemetrySample = {
      id: sampleSeq,
      vehicle_id: v.id,
      trip_id: v.active_trip_id,
      ts: v.last_seen_at,
      lat: v.lat,
      lon: v.lon,
      speed_kmh: v.speed_kmh,
      rpm: v.rpm,
      coolant: v.coolant,
      throttle: v.throttle,
      engine_load: v.engine_load,
      maf: v.maf,
      battery: v.battery,
      fuel_pct: v.fuel_pct,
    }
    telemetryBus.emit({ new: sample })

    // Detecteaza evenimente data-driven din telemetria proaspat actualizata
    detectEvents(v)
  }

  // Avanseaza ghosts
  for (const g of ghosts) {
    g.km_along += g.speed_kmh * dtH
    if (Math.random() < 0.03) {
      g.speed_kmh = Math.max(10, Math.min(70, g.speed_kmh + (Math.random() * 8 - 4)))
    }
  }

  // Notifica listeners care vor snapshot la fleet_status
  stateBus.emit({ vehicles: [...vehicles] })

  // Injecteaza ocazional comportamente brute pe vehicule mock — declanseaza
  // harsh_brake/harsh_accel/speeding detectate de detectEvents la urmatorul tick
  if (Date.now() >= nextAmbientAt) {
    injectDrivingSpike()
    nextAmbientAt = Date.now() + 25_000 + Math.random() * 20_000
  }
}

/** Provoaca un comportament brusc pe un vehicul mock random — declanseaza
 *  events naturali in detectEvents la urmatoarele tick-uri. */
function injectDrivingSpike() {
  // Doar pe vehicule mock (NU device-ul real)
  const eligible = vehicles.filter(
    (v) => v.id !== REAL_DEVICE_VEHICLE_ID && v.status !== 'offline',
  )
  if (eligible.length === 0) return
  const v = eligible[Math.floor(Math.random() * eligible.length)]

  const pick = Math.random()
  if (pick < 0.4 && v.speed_kmh > 15) {
    // Franare brusca — drop target_speed la 0 (decelereaza rapid)
    v.target_speed_kmh = 0
  } else if (pick < 0.7) {
    // Accelerare brusca — sare la target maximal
    const p = personalities.get(v.id)
    if (p) {
      v.target_speed_kmh = (p.baseSpeed + p.variance * 2) * v.speed_factor
      v.speed_kmh = Math.max(v.speed_kmh, v.target_speed_kmh - 1) // boost imediat
    }
  } else {
    // Speeding — boost peste limita
    v.target_speed_kmh = 75 + Math.random() * 15
    v.speed_kmh = v.target_speed_kmh - 1
  }
}

// ============ EVENT DETECTION — data-driven ============

/** Emite un event cu cooldown; daca acelasi tip s-a emis recent pentru
 *  vehiculul respectiv, se ignora (previne spam). */
function emitVehicleEvent(
  v: VehicleState,
  type: string,
  severity: 'info' | 'warning' | 'critical',
  title: string,
  description: string,
  extraPayload?: Record<string, unknown>,
) {
  const state = eventStateByVehicle.get(v.id)
  if (state) {
    const last = state.lastEmittedAt[type]
    const cooldown = EVENT_COOLDOWN_MS[type] ?? 30_000
    if (last && Date.now() - last < cooldown) return
    state.lastEmittedAt[type] = Date.now()
  }
  const event: FleetEvent = {
    id: randomUuid(),
    vehicle_id: v.id,
    trip_id: v.active_trip_id,
    ts: new Date().toISOString(),
    type,
    severity,
    code: null,
    title,
    description,
    payload: extraPayload ?? {},
    resolved_at: null,
  }
  recentEvents.unshift(event)
  if (recentEvents.length > 200) recentEvents.length = 200
  eventsBus.emit({ new: event })
}

/** Analizeaza un sample telemetrie si emite evenimente potrivite.
 *  Apelat din tick() pentru vehicule mock si din applyRealTelemetry pentru
 *  device-ul real conectat. */
function detectEvents(v: VehicleState) {
  let state = eventStateByVehicle.get(v.id)
  const now = Date.now()
  if (!state) {
    state = {
      prevSpeed: v.speed_kmh,
      prevFuel: v.fuel_pct,
      prevBattery: v.battery,
      prevTimestamp: now,
      speedZeroSinceMs: null,
      lastEmittedAt: {},
    }
    eventStateByVehicle.set(v.id, state)
    return
  }

  const dtSec = Math.max(0.05, (now - state.prevTimestamp) / 1000)

  // 1. HARSH BRAKE — deceleratie > prag, viteza prealabila > 5 km/h
  const dV = v.speed_kmh - state.prevSpeed
  const accelMs2 = dV / 3.6 / dtSec
  if (
    accelMs2 < -THRESHOLDS.harshBrakeMs2 &&
    state.prevSpeed > 5
  ) {
    emitVehicleEvent(
      v,
      'harsh_brake',
      'warning',
      `Franare brusca — ${v.plate}`,
      `Deceleratie ${(-accelMs2).toFixed(1)} m/s² la viteza ${state.prevSpeed.toFixed(0)} km/h.`,
      { decel_ms2: -accelMs2, speed_before: state.prevSpeed },
    )
  }

  // 2. HARSH ACCEL
  if (accelMs2 > THRESHOLDS.harshAccelMs2) {
    emitVehicleEvent(
      v,
      'harsh_accel',
      'info',
      `Accelerare brusca — ${v.plate}`,
      `Acceleratie ${accelMs2.toFixed(1)} m/s² — consum crescut.`,
      { accel_ms2: accelMs2 },
    )
  }

  // 3. SPEEDING — limite diferite pentru camioane vs masini
  const isTruck =
    v.make === 'Mercedes-Benz' || v.make === 'Renault'
  const speedLimit = isTruck
    ? THRESHOLDS.truckSpeedingKmh
    : THRESHOLDS.speedingKmh
  if (v.speed_kmh > speedLimit) {
    emitVehicleEvent(
      v,
      'speeding',
      'warning',
      `Depasire limita viteza — ${v.plate}`,
      `Viteza ${v.speed_kmh.toFixed(0)} km/h depaseste ${speedLimit} km/h (zona ${isTruck ? 'autostrada' : 'urbana'}).`,
      { speed: v.speed_kmh, limit: speedLimit },
    )
  }

  // 4. IDLE LONG — vehicul stat fara miscare > 2 min
  // NOTA: skip pentru device-ul real (poate fi parcat intentionat in laborator)
  if (v.id !== REAL_DEVICE_VEHICLE_ID) {
    if (v.speed_kmh < 2) {
      if (state.speedZeroSinceMs == null) {
        state.speedZeroSinceMs = now
      } else if (now - state.speedZeroSinceMs > THRESHOLDS.idleSecMs) {
        emitVehicleEvent(
          v,
          'idle_long',
          'info',
          `Idle prelungit — ${v.plate}`,
          'Motor pornit fara miscare peste 2 minute.',
        )
      }
    } else {
      state.speedZeroSinceMs = null
    }
  }

  // 5. LOW FUEL — edge transition (cand traverseaza pragul)
  if (v.fuel_pct < THRESHOLDS.lowFuelPct && state.prevFuel >= THRESHOLDS.lowFuelPct) {
    emitVehicleEvent(
      v,
      'low_fuel',
      'warning',
      `Combustibil sub 20% — ${v.plate}`,
      `Nivel curent ${v.fuel_pct.toFixed(0)}%. Alimenteaza la urmatoarea oportunitate.`,
      { fuel_pct: v.fuel_pct },
    )
  }

  // 6. LOW BATTERY — edge transition
  if (v.battery < THRESHOLDS.lowBatteryV && state.prevBattery >= THRESHOLDS.lowBatteryV) {
    emitVehicleEvent(
      v,
      'low_battery',
      'critical',
      `Tensiune baterie critica — ${v.plate}`,
      `Tensiune ${v.battery.toFixed(1)}V — sub 11.5V indica probleme alternator.`,
      { battery_v: v.battery },
    )
  }

  // 7. OVERHEAT
  if (v.coolant > THRESHOLDS.overheatC) {
    emitVehicleEvent(
      v,
      'overheat_mild',
      'warning',
      `Coolant ridicat — ${v.plate}`,
      `Temperatura motor ${v.coolant.toFixed(0)}°C. Monitorizeaza, opreste daca creste.`,
      { coolant_c: v.coolant },
    )
  }

  // 8. REDLINE
  if (v.rpm > THRESHOLDS.redlineRpm) {
    emitVehicleEvent(
      v,
      'redline',
      'info',
      `RPM in redline — ${v.plate}`,
      `Turatie ${v.rpm.toFixed(0)} RPM. Schimba treapta superioara.`,
      { rpm: v.rpm },
    )
  }

  // Update prev state
  state.prevSpeed = v.speed_kmh
  state.prevFuel = v.fuel_pct
  state.prevBattery = v.battery
  state.prevTimestamp = now
}

// ============ TRIGGER-E PUBLICE (Demo Control Panel) ============

export function triggerDtc(
  vehicleId: string,
  code: string,
  title: string,
  description: string,
) {
  const v = vehicles.find((x) => x.id === vehicleId)
  if (!v) return
  v.status = 'alert'
  const event: FleetEvent = {
    id: randomUuid(),
    vehicle_id: v.id,
    trip_id: v.active_trip_id,
    ts: new Date().toISOString(),
    type: 'dtc',
    severity: 'critical',
    code,
    title,
    description,
    payload: { code },
    resolved_at: null,
  }
  recentEvents.unshift(event)
  if (recentEvents.length > 200) recentEvents.length = 200
  eventsBus.emit({ new: event })
}

export function triggerLowBattery(vehicleId: string) {
  const v = vehicles.find((x) => x.id === vehicleId)
  if (!v) return
  v.battery = 11.2
  v.status = 'alert'
  const event: FleetEvent = {
    id: randomUuid(),
    vehicle_id: v.id,
    trip_id: v.active_trip_id,
    ts: new Date().toISOString(),
    type: 'low_battery',
    severity: 'critical',
    code: null,
    title: `Tensiune baterie critica — ${v.plate}`,
    description:
      'Tensiunea sistemului electric a scazut sub 11.5V — verifica alternatorul.',
    payload: {},
    resolved_at: null,
  }
  recentEvents.unshift(event)
  if (recentEvents.length > 200) recentEvents.length = 200
  eventsBus.emit({ new: event })
}

/**
 * Injecteaza un event REAL primit din Supabase (de ex. DTC scanat de tableta
 * conectata la simulatorul OBD-II hardware) in event bus-ul si lista de
 * evenimente recente. RealDeviceBridge apeleaza asta cand un INSERT pe tabela
 * `events` apare pentru vehiculul tabletei.
 *
 * Dedupe: ignora evenimentele cu id deja vazut (evita duplicate la reconectare
 * realtime + polling fallback).
 */
const seenRealEventIds = new Set<string>()
export function ingestRealEvent(event: FleetEvent): void {
  if (seenRealEventIds.has(event.id)) return
  seenRealEventIds.add(event.id)
  // Limita memorie — pastram doar ultimele 500 id-uri
  if (seenRealEventIds.size > 500) {
    const first = seenRealEventIds.values().next().value
    if (first) seenRealEventIds.delete(first)
  }
  // Marcheaza vehiculul ca in alerta daca evenimentul e critic
  const v = vehicles.find((x) => x.id === event.vehicle_id)
  if (v && event.severity === 'critical' && !event.resolved_at) {
    v.status = 'alert'
  }
  recentEvents.unshift(event)
  if (recentEvents.length > 200) recentEvents.length = 200
  eventsBus.emit({ new: event })
}

export function resolveAlerts(vehicleId: string) {
  const v = vehicles.find((x) => x.id === vehicleId)
  if (!v) return
  v.status = 'driving'
  // resolve toate evenimentele active
  recentEvents.forEach((e) => {
    if (e.vehicle_id === vehicleId && e.resolved_at == null) {
      e.resolved_at = new Date().toISOString()
    }
  })
}

export function setPaused(p: boolean) {
  paused = p
}

export function getPaused() {
  return paused
}

export function setSpeedMultiplier(m: 1 | 2 | 5) {
  speedMultiplier = m
}

export function getSpeedMultiplier() {
  return speedMultiplier
}

// ============ ACCESSORS ============

export function getFleetStatusSnapshot(): FleetStatusRow[] {
  return vehicles.map((v) => ({
    id: v.id,
    vehicle_id: v.id,
    plate: v.plate,
    vin: v.vin,
    make: v.make,
    model: v.model,
    year: v.year,
    color: v.color,
    driver_name: v.driver_name,
    last_seen_at: v.last_seen_at,
    lat: v.lat,
    lon: v.lon,
    speed_kmh: v.speed_kmh,
    rpm: v.rpm,
    coolant: v.coolant,
    throttle: v.throttle,
    engine_load: v.engine_load,
    battery: v.battery,
    fuel_pct: v.fuel_pct,
    active_trip_id: v.active_trip_id,
    status: v.status,
  }))
}

export function getRecentEvents(): FleetEvent[] {
  return [...recentEvents]
}

export function getTrips(): Trip[] {
  return [...trips]
}

export function getVehiclesList(): VehicleState[] {
  return [...vehicles]
}

/** Returneaza trail-ul (log de pozitii) unui vehicul. */
export function getVehicleTrail(vehicleId: string): Array<[number, number]> {
  const v = vehicles.find((x) => x.id === vehicleId)
  return v ? [...v.trail] : []
}

/** Returneaza culoarea brand a unui vehicul (pentru rendering trail). */
export function getVehicleColor(vehicleId: string): string {
  const v = vehicles.find((x) => x.id === vehicleId)
  return v?.color ?? '#00D4FF'
}

/**
 * Aplica telemetrie REALA pentru un vehicul (din Supabase realtime).
 * Suprascrie state-ul vehiculului si emite pe telemetryBus → markerul se misca
 * dupa GPS-ul real. Marcheaza lastRealUpdate ca sa pauzeze simulatorul pentru
 * urmatoarele REAL_AUTHORITATIVE_WINDOW_MS milisecunde.
 */
export function applyRealTelemetry(
  vehicleId: string,
  sample: {
    lat?: number | null
    lon?: number | null
    speed_kmh?: number | null
    rpm?: number | null
    coolant?: number | null
    throttle?: number | null
    engine_load?: number | null
    battery?: number | null
    fuel_pct?: number | null
    maf?: number | null
  },
): void {
  const v = vehicles.find((x) => x.id === vehicleId)
  if (!v) return
  if (sample.lat != null) v.lat = sample.lat
  if (sample.lon != null) v.lon = sample.lon
  if (sample.speed_kmh != null) v.speed_kmh = sample.speed_kmh
  if (sample.rpm != null) v.rpm = sample.rpm
  if (sample.coolant != null) v.coolant = sample.coolant
  if (sample.throttle != null) v.throttle = sample.throttle
  if (sample.engine_load != null) v.engine_load = sample.engine_load
  if (sample.battery != null) v.battery = sample.battery
  if (sample.fuel_pct != null) v.fuel_pct = sample.fuel_pct
  if (sample.maf != null) v.maf = sample.maf

  v.last_seen_at = new Date().toISOString()
  v.status = v.speed_kmh > 3 ? 'driving' : 'idle'
  lastRealUpdate[vehicleId] = Date.now()

  // Emit pe telemetryBus ca FleetMap sa actualizeze markerul
  sampleSeq++
  telemetryBus.emit({
    new: {
      id: sampleSeq,
      vehicle_id: v.id,
      trip_id: v.active_trip_id,
      ts: v.last_seen_at,
      lat: v.lat,
      lon: v.lon,
      speed_kmh: v.speed_kmh,
      rpm: v.rpm,
      coolant: v.coolant,
      throttle: v.throttle,
      engine_load: v.engine_load,
      maf: v.maf,
      battery: v.battery,
      fuel_pct: v.fuel_pct,
    },
  })

  // Detecteaza events din date REALE (harsh brake, speeding, low fuel, etc.)
  detectEvents(v)
}

/** Returneaza toate samples sintetice pentru toate trips (folosit de mock client). */
export function getAllTripSamples(): TelemetrySample[] {
  const all: TelemetrySample[] = []
  for (const arr of tripSamplesMap.values()) all.push(...arr)
  return all
}

/** Genereaza ~200 samples sintetice de-a lungul rutei vehiculului pentru un trip. */
function generateTripSamples(
  vehicle: VehicleState,
  tripId: string,
  startedAtIso: string,
  endedAtIso: string,
  distanceKm: number,
  maxSpeed: number,
  maxRpm: number,
): TelemetrySample[] {
  const route = ROUTES[vehicle.route_id]
  if (!route) return []
  const startMs = new Date(startedAtIso).getTime()
  const endMs = new Date(endedAtIso).getTime()
  const durationMs = Math.max(60_000, endMs - startMs)
  const NUM_SAMPLES = 200
  const samples: TelemetrySample[] = []
  let baseId = Math.floor(Math.random() * 1_000_000) + 1
  const baseCoolant = 78 + Math.random() * 8
  const baseFuel = 50 + Math.random() * 40

  for (let i = 0; i < NUM_SAMPLES; i++) {
    const t = i / (NUM_SAMPLES - 1)
    // Bell-curve viteza (porneste lent, varf in mijloc, frana la final)
    const speedFactor = Math.sin(t * Math.PI) // 0..1..0
    const speed = Math.max(2, maxSpeed * (0.35 + speedFactor * 0.55) + (Math.random() - 0.5) * 8)
    const rpm = 900 + (speed / 60) * (maxRpm - 900) + (Math.random() - 0.5) * 200
    // Pozitie pe ruta — bazata pe distanta cumulativa
    const kmAlong = (t * distanceKm) % route.totalKm
    const pos = interpolateRoute(route, kmAlong)
    const ts = new Date(startMs + t * durationMs).toISOString()
    samples.push({
      id: baseId++,
      vehicle_id: vehicle.id,
      trip_id: tripId,
      ts,
      lat: pos.lat,
      lon: pos.lon,
      speed_kmh: Math.round(speed),
      rpm: Math.round(rpm),
      coolant: baseCoolant + (Math.random() - 0.5) * 4,
      throttle: 15 + speedFactor * 50 + Math.random() * 8,
      engine_load: 25 + speedFactor * 45,
      maf: 4 + speedFactor * 15,
      battery: 13.8 + (Math.random() - 0.5) * 0.3,
      fuel_pct: baseFuel - t * 8, // scade incet
    })
  }
  return samples
}

/** Returneaza pozitiile curente ale ghosts (vehicule ambient). */
export function getGhostPositions(): Array<{
  id: string
  lon: number
  lat: number
}> {
  return ghosts.map((g) => {
    const route = ROUTES[g.route_id]
    if (!route) return { id: g.id, lon: 0, lat: 0 }
    const pos = interpolateRoute(route, g.km_along)
    return { id: g.id, lon: pos.lon, lat: pos.lat }
  })
}

// ============ LIFECYCLE ============

export function start() {
  if (started) return
  if (typeof window === 'undefined') return // niciodata pe server
  init()
  started = true
  intervalId = window.setInterval(tick, TICK_MS)
}

export function stop() {
  if (intervalId != null) {
    clearInterval(intervalId)
    intervalId = null
  }
  started = false
}

// ============ UTIL ============

function randomUuid(): string {
  // Implementare simpla — nu cryptographic, dar suficient pentru demo
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}
