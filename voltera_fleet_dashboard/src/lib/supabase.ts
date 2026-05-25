/**
 * Compat shim: re-exporta clientul browser ca `supabase` (forma veche)
 * pentru ca toate componentele existente sa continue sa functioneze.
 * Pentru server-side, importa direct din `@/lib/supabase/server`.
 *
 * Demo mode: cand NEXT_PUBLIC_DEMO_MODE=true, returneaza un mock client
 * care simuleaza 5 vehicule local, fara backend Supabase necesar.
 */
import { createClient } from './supabase/client'
import { createMockClient, type MockClient } from './mock/client'

const isDemoMode = process.env.NEXT_PUBLIC_DEMO_MODE === 'true'

// Type-cast: mock-ul implementeaza subset-ul de API pe care il foloseste
// dashboard-ul. TypeScript nu poate verifica strict compatibilitatea (nu am
// generat tipuri din schema Supabase), dar la runtime functioneaza.
export const supabase = (
  isDemoMode ? createMockClient() : createClient()
) as unknown as ReturnType<typeof createClient> & MockClient

// ============ Types ============

export type Vehicle = {
  id: string
  plate: string
  vin: string | null
  make: string | null
  model: string | null
  year: number | null
  color: string | null
  driver_name: string | null
}

export type FleetStatusRow = Vehicle & {
  vehicle_id: string
  last_seen_at: string | null
  lat: number | null
  lon: number | null
  speed_kmh: number | null
  rpm: number | null
  coolant: number | null
  throttle: number | null
  engine_load: number | null
  battery: number | null
  fuel_pct: number | null
  active_trip_id: string | null
  status: 'driving' | 'idle' | 'alert' | 'offline'
}

export type TelemetrySample = {
  id: number
  vehicle_id: string
  trip_id: string | null
  ts: string
  lat: number | null
  lon: number | null
  speed_kmh: number | null
  rpm: number | null
  coolant: number | null
  throttle: number | null
  engine_load: number | null
  maf: number | null
  battery: number | null
  fuel_pct: number | null
}

export type FleetEvent = {
  id: string
  vehicle_id: string
  trip_id: string | null
  ts: string
  type: string
  severity: 'info' | 'warning' | 'critical'
  code: string | null
  title: string
  description: string | null
  payload: Record<string, unknown>
  resolved_at: string | null
}

export type Trip = {
  id: string
  vehicle_id: string
  driver_name: string | null
  started_at: string
  ended_at: string | null
  distance_km: number | null
  fuel_l: number | null
  max_speed_kmh: number | null
  max_rpm: number | null
  eco_score: number | null
}
