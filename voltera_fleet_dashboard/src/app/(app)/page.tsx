'use client'

import dynamic from 'next/dynamic'
import { useEffect, useMemo, useState } from 'react'
import type maplibregl from 'maplibre-gl'
import { supabase, type FleetStatusRow } from '@/lib/supabase'
import VehicleDrawer from '@/components/VehicleDrawer'
import AlertsTicker from '@/components/AlertsTicker'
import AIInsightsPanel from '@/components/AIInsightsPanel'
import TelemetryConstellation from '@/components/TelemetryConstellation'
import { constellationFlag } from '@/lib/ui-state'
import { Activity, Search } from 'lucide-react'

const FleetMap = dynamic(() => import('@/components/FleetMap'), { ssr: false })

export default function FleetDashboard() {
  const [vehicles, setVehicles] = useState<FleetStatusRow[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [filter, setFilter] = useState('')
  const [livePositions, setLivePositions] = useState<
    Record<string, { lat: number; lon: number; ts: number }>
  >({})
  const [mapInstance, setMapInstance] = useState<maplibregl.Map | null>(null)
  const [constellation, setConstellation] = useState(false)

  useEffect(() => {
    setConstellation(constellationFlag.get())
    const unsub = constellationFlag.subscribe(setConstellation)
    return () => {
      unsub()
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    async function refresh() {
      const { data } = await supabase
        .from('fleet_status')
        .select('*')
        .order('plate', { ascending: true })
      if (!cancelled && data) setVehicles(data as FleetStatusRow[])
    }

    refresh()
    const id = setInterval(refresh, 5000)
    return () => {
      cancelled = true
      clearInterval(id)
    }
  }, [])

  const selected = useMemo(
    () => vehicles.find((v) => v.vehicle_id === selectedId) ?? null,
    [vehicles, selectedId],
  )

  const filtered = useMemo(() => {
    if (!filter.trim()) return vehicles
    const q = filter.toLowerCase()
    return vehicles.filter(
      (v) =>
        (v.plate ?? '').toLowerCase().includes(q) ||
        (v.driver_name ?? '').toLowerCase().includes(q) ||
        (v.make ?? '').toLowerCase().includes(q) ||
        (v.model ?? '').toLowerCase().includes(q),
    )
  }, [vehicles, filter])

  const counts = useMemo(() => {
    const c = { driving: 0, idle: 0, alert: 0, offline: 0 }
    vehicles.forEach((v) => (c[v.status] = (c[v.status] ?? 0) + 1))
    return c
  }, [vehicles])

  const spotlightActive = selected != null

  return (
    <div className="relative h-full w-full">
      {/* Map fundal — filter aplicat cand un vehicul e selectat (spotlight) */}
      <div
        className="absolute inset-0 transition-[filter] duration-500 ease-out"
        style={{
          transitionTimingFunction: 'cubic-bezier(0.25, 1, 0.5, 1)',
          filter: spotlightActive ? 'var(--spotlight-filter)' : 'none',
        }}
      >
        <FleetMap
          vehicles={vehicles}
          onSelect={setSelectedId}
          selectedId={selectedId}
          onLivePosition={(id, lat, lon) =>
            setLivePositions((p) => ({
              ...p,
              [id]: { lat, lon, ts: Date.now() },
            }))
          }
          onMapReady={setMapInstance}
        />
      </div>

      {/* Telemetry Constellation 3D overlay */}
      <TelemetryConstellation
        active={constellation}
        map={mapInstance}
        vehicles={vehicles}
        livePositions={livePositions}
      />

      {/* Vignette overlay — focus pe vehicul cand spotlight activ */}
      <div
        className={`pointer-events-none absolute inset-0 z-[5] transition-opacity duration-500 ease-out ${
          spotlightActive ? 'opacity-100' : 'opacity-0'
        }`}
        style={{ background: 'var(--spotlight-vignette)' }}
      />

      {/* Status pills (top-center floating) */}
      <div className="pointer-events-none absolute left-1/2 top-4 z-10 flex -translate-x-1/2 items-center gap-1.5">
        <StatusPill color="ok" label="DRIVING" value={counts.driving} />
        <StatusPill color="warn" label="IDLE" value={counts.idle} />
        <StatusPill color="danger" label="ALERT" value={counts.alert} />
        <StatusPill color="textMuted" label="OFFLINE" value={counts.offline} />
      </div>

      {/* Fleet sidebar */}
      <aside className="pointer-events-auto absolute left-4 top-4 z-10 w-[280px] overflow-hidden rounded-2xl border border-border/70 bg-surface/85 shadow-2xl backdrop-blur-xl">
        <div className="border-b border-border/60 px-3 py-3">
          <div className="mb-2 flex items-center justify-between">
            <span className="flex items-center gap-1.5 font-display text-[10px] font-black tracking-widest text-textMuted">
              <Activity size={12} className="text-cyan" /> FLOTA LIVE
            </span>
            <span className="rounded bg-cyan/10 px-1.5 py-0.5 font-mono text-[10px] font-bold text-cyan">
              {filtered.length}/{vehicles.length}
            </span>
          </div>
          <div className="relative">
            <Search
              size={12}
              className="absolute left-2.5 top-1/2 -translate-y-1/2 text-textDim"
            />
            <input
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              placeholder="cauta sofer / plate / model..."
              className="w-full rounded-md border border-border/60 bg-bg/60 py-1.5 pl-7 pr-2 text-xs text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none"
            />
          </div>
        </div>
        <ul className="max-h-[60vh] space-y-1 overflow-y-auto p-2">
          {filtered.map((v) => {
            const isLive =
              v.last_seen_at &&
              Date.now() - new Date(v.last_seen_at).getTime() < 10_000
            return (
              <li
                key={v.vehicle_id}
                onClick={() => setSelectedId(v.vehicle_id)}
                className={`cursor-pointer rounded-lg border p-2 transition ${
                  selectedId === v.vehicle_id
                    ? 'border-cyan bg-cyan/10 shadow-[0_0_24px_-4px_rgba(0,212,255,0.45)]'
                    : 'border-border/50 bg-surface/40 hover:border-cyan/40 hover:bg-surface/70'
                }`}
              >
                <div className="flex items-center gap-2">
                  <span
                    className={`relative h-2.5 w-2.5 rounded-full ${
                      isLive ? 'animate-pulse' : ''
                    }`}
                    style={{
                      background:
                        v.status === 'driving'
                          ? '#00E676'
                          : v.status === 'alert'
                            ? '#FF1744'
                            : v.status === 'idle'
                              ? '#FFC400'
                              : '#4A5260',
                      boxShadow: isLive ? `0 0 8px currentColor` : 'none',
                    }}
                  />
                  <span className="font-display text-sm font-bold tracking-wider text-white">
                    {v.plate}
                  </span>
                  <span className="ml-auto font-mono text-[11px] tabular-nums text-textMuted">
                    {(v.speed_kmh ?? 0).toFixed(0)}
                    <span className="ml-0.5 text-[9px] text-textDim">km/h</span>
                  </span>
                </div>
                <p className="mt-0.5 truncate text-[11px] text-textMuted">
                  {v.driver_name ?? '—'} · {v.make} {v.model}
                </p>
              </li>
            )
          })}
          {filtered.length === 0 && (
            <p className="px-2 py-6 text-center text-xs text-textDim">
              {vehicles.length === 0
                ? 'Niciun vehicul. Ruleaza seed-ul SQL.'
                : 'Niciun rezultat.'}
            </p>
          )}
        </ul>
      </aside>

      {/* Alerts inbox (cand drawer e inchis) */}
      {!selected && <AlertsTicker onSelectVehicle={setSelectedId} />}

      {/* AI Insights — bottom-left, vizibil mereu (nu intra in coliziune cu drawer-ul) */}
      {!selected && <AIInsightsPanel />}

      {/* Drawer detalii vehicul — contine deja toate KPI-urile + GPS, deci
          KPI bar de jos NU mai e nevoie cat timp drawer-ul e deschis. */}
      {selected && (
        <VehicleDrawer
          vehicle={selected}
          livePos={livePositions[selected.vehicle_id]}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  )
}

function StatusPill({
  color,
  label,
  value,
}: {
  color: 'ok' | 'warn' | 'danger' | 'textMuted'
  label: string
  value: number
}) {
  const cls = {
    ok: 'border-ok/40 text-ok bg-ok/10',
    warn: 'border-warn/40 text-warn bg-warn/10',
    danger: 'border-danger/40 text-danger bg-danger/10',
    textMuted: 'border-border/60 text-textMuted bg-surface/40',
  }[color]
  return (
    <span
      className={`pointer-events-auto flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-display text-[10px] font-bold tracking-widest backdrop-blur-md ${cls}`}
    >
      {label}
      <span className="font-mono text-white tabular-nums">{value}</span>
    </span>
  )
}

