'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import {
  supabase,
  type FleetStatusRow,
  type FleetEvent,
  type Trip,
  type TelemetrySample,
} from '@/lib/supabase'
import {
  Gauge,
  Thermometer,
  Battery,
  Activity,
  Fuel,
  AlertTriangle,
  Route,
  X,
  Wind,
  MapPin,
} from 'lucide-react'

type Props = {
  vehicle: FleetStatusRow
  livePos?: { lat: number; lon: number; ts: number }
  onClose: () => void
}

export default function VehicleDrawer({ vehicle, livePos, onClose }: Props) {
  const [events, setEvents] = useState<FleetEvent[]>([])
  const [trips, setTrips] = useState<Trip[]>([])
  const [liveTelemetry, setLiveTelemetry] = useState<{
    speed: number
    rpm: number
    coolant: number
    throttle: number
    battery: number
    fuel: number
  } | null>(null)

  useEffect(() => {
    let cancelled = false

    async function loadHistory() {
      const [{ data: evData }, { data: tripData }] = await Promise.all([
        supabase
          .from('events')
          .select('*')
          .eq('vehicle_id', vehicle.vehicle_id)
          .order('ts', { ascending: false })
          .limit(10),
        supabase
          .from('trips')
          .select('*')
          .eq('vehicle_id', vehicle.vehicle_id)
          .order('started_at', { ascending: false })
          .limit(5),
      ])
      if (cancelled) return
      setEvents((evData ?? []) as FleetEvent[])
      setTrips((tripData ?? []) as Trip[])
    }

    loadHistory()

    const channel = supabase
      .channel(`vehicle-${vehicle.vehicle_id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'events',
          filter: `vehicle_id=eq.${vehicle.vehicle_id}`,
        },
        (payload) => {
          setEvents((prev) =>
            [payload.new as FleetEvent, ...prev].slice(0, 10),
          )
        },
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'telemetry_samples',
          filter: `vehicle_id=eq.${vehicle.vehicle_id}`,
        },
        (payload) => {
          const s = payload.new as TelemetrySample
          setLiveTelemetry({
            speed: s.speed_kmh ?? 0,
            rpm: s.rpm ?? 0,
            coolant: s.coolant ?? 0,
            throttle: s.throttle ?? 0,
            battery: s.battery ?? 0,
            fuel: s.fuel_pct ?? 0,
          })
        },
      )
      .subscribe()

    return () => {
      cancelled = true
      supabase.removeChannel(channel)
    }
  }, [vehicle.vehicle_id])

  // Valorile live (din realtime) au prioritate fata de cele din poll
  const liveSpeed = liveTelemetry?.speed ?? vehicle.speed_kmh ?? 0
  const liveRpm = liveTelemetry?.rpm ?? vehicle.rpm ?? 0
  const liveCoolant = liveTelemetry?.coolant ?? vehicle.coolant ?? 0
  const liveThrottle = liveTelemetry?.throttle ?? vehicle.throttle ?? 0
  const liveBattery = liveTelemetry?.battery ?? vehicle.battery ?? 0
  const liveFuel = liveTelemetry?.fuel ?? vehicle.fuel_pct ?? 0

  const sevColor = (s: FleetEvent['severity']) =>
    s === 'critical'
      ? 'border-danger/50 bg-danger/5 text-danger'
      : s === 'warning'
        ? 'border-warn/50 bg-warn/5 text-warn'
        : 'border-cyan/50 bg-cyan/5 text-cyan'

  const statusBadge =
    vehicle.status === 'driving'
      ? { cls: 'border-ok/60 bg-ok/10 text-ok', label: 'DRIVING' }
      : vehicle.status === 'alert'
        ? { cls: 'border-danger/60 bg-danger/10 text-danger', label: 'ALERT' }
        : vehicle.status === 'idle'
          ? { cls: 'border-warn/60 bg-warn/10 text-warn', label: 'IDLE' }
          : { cls: 'border-border/60 text-textMuted', label: 'OFFLINE' }

  const lat = livePos?.lat ?? vehicle.lat
  const lon = livePos?.lon ?? vehicle.lon
  const liveAgoSec = livePos
    ? Math.max(0, Math.round((Date.now() - livePos.ts) / 1000))
    : null

  return (
    <aside className="drawer-slide-in fixed bottom-4 right-4 top-[68px] z-30 flex w-[420px] flex-col overflow-hidden rounded-2xl border border-border/70 bg-bg/95 shadow-[0_12px_50px_-12px_rgba(0,212,255,0.45),0_0_0_1px_rgba(0,212,255,0.08)] backdrop-blur-xl">
      {/* HEADER vehicul — fix in top-ul card-ului */}
      <header className="flex shrink-0 items-start justify-between gap-3 border-b border-border/60 bg-surface/40 p-5">
        <div className="flex min-w-0 items-center gap-3">
          <div
            className="h-10 w-10 shrink-0 rounded-xl ring-2 ring-white/10 shadow-[0_0_18px_-4px]"
            style={{
              background: vehicle.color ?? '#22d3ee',
              boxShadow: `0 0 24px -4px ${vehicle.color ?? '#22d3ee'}`,
            }}
          />
          <div className="min-w-0">
            <h2 className="truncate font-display text-lg font-black tracking-wider">
              {vehicle.plate}
            </h2>
            <p className="truncate text-xs text-textMuted">
              {vehicle.make} {vehicle.model} {vehicle.year ?? ''}
            </p>
            <p className="truncate text-[11px] text-textDim">
              {vehicle.driver_name ?? 'fara sofer alocat'}
            </p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="shrink-0 rounded-full border border-border/60 bg-surface p-1.5 text-textMuted transition hover:border-danger/40 hover:text-danger"
          aria-label="Inchide"
        >
          <X size={16} />
        </button>
      </header>

      {/* CONTAINER SCROLLABIL */}
      <div className="flex-1 overflow-y-auto pb-6">

      {/* STATUS + GPS card */}
      <section className="space-y-3 p-5">
        <div className="flex items-center gap-2">
          <span
            className={`rounded-full border px-3 py-1 font-display text-[10px] font-bold tracking-widest ${statusBadge.cls}`}
          >
            {statusBadge.label}
          </span>
          <span className="text-[10px] uppercase tracking-widest text-textDim">
            ultim update{' '}
            {vehicle.last_seen_at
              ? new Date(vehicle.last_seen_at).toLocaleTimeString('ro-RO')
              : '—'}
          </span>
        </div>

        {lat != null && lon != null && (
          <div className="flex items-center gap-3 rounded-xl border border-cyan/20 bg-cyan/5 p-3">
            <MapPin size={18} className="shrink-0 text-cyan" />
            <div className="min-w-0 flex-1">
              <div className="font-mono text-xs tabular-nums text-white">
                {lat.toFixed(5)}, {lon.toFixed(5)}
              </div>
              <div className="text-[10px] text-textMuted">
                {liveAgoSec != null
                  ? `realtime · ${liveAgoSec}s ago`
                  : 'din fleet_status (poll 5s)'}
              </div>
            </div>
            {liveAgoSec != null && liveAgoSec < 5 && (
              <span className="relative flex h-2 w-2 shrink-0">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-cyan opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-cyan" />
              </span>
            )}
          </div>
        )}
      </section>

      {/* METRICI — text simplu, fara cadrane */}
      <section className="grid grid-cols-3 gap-2 px-5">
        <Metric icon={<Gauge size={14} />} label="VITEZA" value={liveSpeed} unit="km/h" decimals={0} />
        <Metric icon={<Activity size={14} />} label="RPM" value={liveRpm} unit="" decimals={0} />
        <Metric icon={<Thermometer size={14} />} label="COOLANT" value={liveCoolant} unit="°C" decimals={0} />
        <Metric icon={<Battery size={14} />} label="BAT" value={liveBattery} unit="V" decimals={1} />
        <Metric icon={<Fuel size={14} />} label="FUEL" value={liveFuel} unit="%" decimals={0} />
        <Metric icon={<Wind size={14} />} label="THROTTLE" value={liveThrottle} unit="%" decimals={0} />
      </section>

      {/* EVENTS */}
      <section className="mt-6 px-5">
        <h3 className="mb-2 flex items-center justify-between">
          <span className="flex items-center gap-2 font-display text-[11px] font-bold tracking-widest text-textMuted">
            <AlertTriangle size={13} /> EVENTS · LIVE
          </span>
          <span className="rounded bg-surface px-1.5 py-0.5 font-mono text-[10px] text-textMuted">
            {events.length}
          </span>
        </h3>
        {events.length === 0 && (
          <p className="rounded-lg border border-border/60 bg-surface/40 p-3 text-xs text-textDim">
            Niciun event inregistrat.
          </p>
        )}
        <ul className="space-y-1.5">
          {events.map((e) => (
            <li
              key={e.id}
              className={`rounded-lg border p-2.5 ${sevColor(e.severity)}`}
            >
              <div className="flex items-center justify-between gap-2">
                <span className="font-display text-xs font-black tracking-wider">
                  {e.code ?? e.type.toUpperCase()}
                </span>
                <span className="font-mono text-[10px] text-textMuted">
                  {new Date(e.ts).toLocaleTimeString('ro-RO')}
                </span>
              </div>
              <p className="mt-1 text-sm text-white">{e.title}</p>
              {e.description && (
                <p className="mt-0.5 line-clamp-2 text-[11px] text-textMuted">
                  {e.description}
                </p>
              )}
            </li>
          ))}
        </ul>
      </section>

      {/* TRIPS */}
      <section className="my-6 px-5">
        <h3 className="mb-2 flex items-center justify-between">
          <span className="flex items-center gap-2 font-display text-[11px] font-bold tracking-widest text-textMuted">
            <Route size={13} /> TRASEE
          </span>
          <span className="rounded bg-surface px-1.5 py-0.5 font-mono text-[10px] text-textMuted">
            {trips.length}
          </span>
        </h3>
        {trips.length === 0 && (
          <p className="rounded-lg border border-border/60 bg-surface/40 p-3 text-xs text-textDim">
            Nicio sesiune inregistrata.
          </p>
        )}
        <ul className="space-y-1.5">
          {trips.map((t) => (
            <li
              key={t.id}
              className="overflow-hidden rounded-lg border border-border/60 bg-surface/40 transition hover:border-cyan/60 hover:bg-surface/70"
            >
              <Link href={`/trips/${t.id}`} className="block p-2.5">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] text-textMuted">
                    {new Date(t.started_at).toLocaleString('ro-RO')}
                  </span>
                  <span className="rounded bg-cyan/15 px-2 py-0.5 font-display text-[10px] font-black tracking-wider text-cyan">
                    REPLAY →
                  </span>
                </div>
                <div className="mt-1.5 flex gap-4">
                  <Stat
                    label="DIST"
                    value={`${(t.distance_km ?? 0).toFixed(1)}`}
                    unit="km"
                  />
                  <Stat
                    label="MAX"
                    value={`${(t.max_speed_kmh ?? 0).toFixed(0)}`}
                    unit="km/h"
                  />
                  <Stat label="ECO" value={`${t.eco_score ?? 0}`} unit="" />
                </div>
              </Link>
            </li>
          ))}
        </ul>
      </section>

      </div>{/* end CONTAINER SCROLLABIL */}
    </aside>
  )
}

function Metric({
  icon,
  label,
  value,
  unit,
  decimals = 1,
}: {
  icon: React.ReactNode
  label: string
  value: number
  unit: string
  decimals?: number
}) {
  return (
    <div className="rounded-lg border border-border/60 bg-surface/40 p-2.5">
      <div className="flex items-center gap-1 text-[9px] uppercase tracking-widest text-textMuted">
        {icon} {label}
      </div>
      <div className="mt-0.5 font-display text-lg font-black leading-tight text-white">
        {value.toFixed(decimals)}
        {unit && (
          <span className="ml-0.5 text-[10px] font-medium text-textMuted">
            {unit}
          </span>
        )}
      </div>
    </div>
  )
}

function Stat({
  label,
  value,
  unit,
}: {
  label: string
  value: string
  unit: string
}) {
  return (
    <div>
      <div className="text-[9px] uppercase tracking-widest text-textDim">
        {label}
      </div>
      <div className="font-display text-sm font-black text-white">
        {value}
        {unit && (
          <span className="ml-0.5 text-[10px] font-medium text-textMuted">
            {unit}
          </span>
        )}
      </div>
    </div>
  )
}
