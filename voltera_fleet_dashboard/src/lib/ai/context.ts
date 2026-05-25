import { createClient } from '@/lib/supabase/server'

export type FleetSnapshot = {
  capturedAt: string
  vehicles: Array<{
    plate: string
    driver: string | null
    make: string | null
    model: string | null
    status: string
    speed_kmh: number | null
    rpm: number | null
    coolant: number | null
    fuel_pct: number | null
    battery: number | null
    last_seen_at: string | null
  }>
  recentEvents: Array<{
    ts: string
    plate: string | null
    severity: string
    type: string
    code: string | null
    title: string
    description: string | null
    resolved: boolean
  }>
  recentTrips: Array<{
    plate: string | null
    driver: string | null
    started_at: string
    ended_at: string | null
    distance_km: number | null
    fuel_l: number | null
    max_speed_kmh: number | null
    eco_score: number | null
  }>
}

export async function getFleetSnapshot(opts?: {
  eventLimit?: number
  tripLimit?: number
}): Promise<FleetSnapshot> {
  const eventLimit = opts?.eventLimit ?? 25
  const tripLimit = opts?.tripLimit ?? 10
  const supabase = createClient()

  const [fleetRes, eventsRes, tripsRes] = await Promise.all([
    supabase.from('fleet_status').select('*').order('plate', { ascending: true }),
    supabase
      .from('events')
      .select('*')
      .order('ts', { ascending: false })
      .limit(eventLimit),
    supabase
      .from('trips')
      .select('*')
      .order('started_at', { ascending: false })
      .limit(tripLimit),
  ])

  const fleet = (fleetRes.data ?? []) as Array<Record<string, unknown>>
  const plateByVehicleId = new Map<string, string>()
  const driverByVehicleId = new Map<string, string | null>()
  for (const row of fleet) {
    const vid = row.vehicle_id as string | undefined
    if (!vid) continue
    plateByVehicleId.set(vid, (row.plate as string) ?? vid)
    driverByVehicleId.set(vid, (row.driver_name as string) ?? null)
  }

  return {
    capturedAt: new Date().toISOString(),
    vehicles: fleet.map((v) => ({
      plate: (v.plate as string) ?? '—',
      driver: (v.driver_name as string) ?? null,
      make: (v.make as string) ?? null,
      model: (v.model as string) ?? null,
      status: (v.status as string) ?? 'offline',
      speed_kmh: (v.speed_kmh as number) ?? null,
      rpm: (v.rpm as number) ?? null,
      coolant: (v.coolant as number) ?? null,
      fuel_pct: (v.fuel_pct as number) ?? null,
      battery: (v.battery as number) ?? null,
      last_seen_at: (v.last_seen_at as string) ?? null,
    })),
    recentEvents: ((eventsRes.data ?? []) as Array<Record<string, unknown>>).map(
      (e) => ({
        ts: e.ts as string,
        plate: plateByVehicleId.get(e.vehicle_id as string) ?? null,
        severity: (e.severity as string) ?? 'info',
        type: (e.type as string) ?? '—',
        code: (e.code as string) ?? null,
        title: (e.title as string) ?? '—',
        description: (e.description as string) ?? null,
        resolved: Boolean(e.resolved_at),
      }),
    ),
    recentTrips: ((tripsRes.data ?? []) as Array<Record<string, unknown>>).map(
      (t) => ({
        plate: plateByVehicleId.get(t.vehicle_id as string) ?? null,
        driver: driverByVehicleId.get(t.vehicle_id as string) ?? null,
        started_at: t.started_at as string,
        ended_at: (t.ended_at as string) ?? null,
        distance_km: (t.distance_km as number) ?? null,
        fuel_l: (t.fuel_l as number) ?? null,
        max_speed_kmh: (t.max_speed_kmh as number) ?? null,
        eco_score: (t.eco_score as number) ?? null,
      }),
    ),
  }
}

export function snapshotToMarkdown(snap: FleetSnapshot): string {
  const lines: string[] = []
  lines.push(`# Stare flota la ${new Date(snap.capturedAt).toLocaleString('ro-RO')}`)
  lines.push('')
  lines.push('## Vehicule')
  if (snap.vehicles.length === 0) lines.push('- (niciun vehicul inregistrat)')
  for (const v of snap.vehicles) {
    const km = v.speed_kmh != null ? `${v.speed_kmh.toFixed(0)} km/h` : '—'
    const rpm = v.rpm != null ? `${v.rpm.toFixed(0)} rpm` : '—'
    const fuel = v.fuel_pct != null ? `combustibil ${v.fuel_pct.toFixed(0)}%` : ''
    const coolant = v.coolant != null ? `lichid racire ${v.coolant.toFixed(0)}°C` : ''
    lines.push(
      `- ${v.plate} (${v.make ?? '—'} ${v.model ?? ''}) · sofer ${v.driver ?? '—'} · status ${v.status} · ${km} · ${rpm}${fuel ? ' · ' + fuel : ''}${coolant ? ' · ' + coolant : ''}`,
    )
  }
  lines.push('')
  lines.push('## Evenimente recente (cele mai noi prima)')
  if (snap.recentEvents.length === 0) lines.push('- (niciun eveniment)')
  for (const e of snap.recentEvents) {
    const when = new Date(e.ts).toLocaleString('ro-RO')
    const code = e.code ? ` [${e.code}]` : ''
    const resolved = e.resolved ? ' (REZOLVAT)' : ''
    lines.push(
      `- ${when} · ${e.plate ?? '—'} · ${e.severity.toUpperCase()}${code} · ${e.title}${resolved}`,
    )
  }
  lines.push('')
  lines.push('## Trasee recente')
  if (snap.recentTrips.length === 0) lines.push('- (niciun traseu inregistrat)')
  for (const t of snap.recentTrips) {
    const when = new Date(t.started_at).toLocaleString('ro-RO')
    const dist = t.distance_km != null ? `${t.distance_km.toFixed(1)} km` : '—'
    const fuel = t.fuel_l != null ? `${t.fuel_l.toFixed(1)} L` : '—'
    const max = t.max_speed_kmh != null ? `max ${t.max_speed_kmh.toFixed(0)} km/h` : ''
    const eco = t.eco_score != null ? `eco ${t.eco_score}/100` : ''
    lines.push(
      `- ${when} · ${t.plate ?? '—'} (${t.driver ?? '—'}) · ${dist} · ${fuel}${max ? ' · ' + max : ''}${eco ? ' · ' + eco : ''}`,
    )
  }
  return lines.join('\n')
}
