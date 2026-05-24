'use client'

import { useEffect, useState, use } from 'react'
import Link from 'next/link'
import {
  supabase,
  type FleetStatusRow,
  type FleetEvent,
  type Trip,
} from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { Card, CardHeader, StatCard } from '@/components/ui/Card'
import StatusBadge from '@/components/ui/StatusBadge'
import {
  Gauge,
  Activity,
  Thermometer,
  Battery,
  Fuel,
  ArrowLeft,
  AlertTriangle,
  Route,
  MapPin,
} from 'lucide-react'

export default function VehicleDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = use(params)
  const [vehicle, setVehicle] = useState<FleetStatusRow | null>(null)
  const [events, setEvents] = useState<FleetEvent[]>([])
  const [trips, setTrips] = useState<Trip[]>([])

  useEffect(() => {
    let cancelled = false
    async function load() {
      const [{ data: v }, { data: ev }, { data: tr }] = await Promise.all([
        supabase
          .from('fleet_status')
          .select('*')
          .eq('vehicle_id', id)
          .maybeSingle(),
        supabase
          .from('events')
          .select('*')
          .eq('vehicle_id', id)
          .order('ts', { ascending: false })
          .limit(20),
        supabase
          .from('trips')
          .select('*')
          .eq('vehicle_id', id)
          .order('started_at', { ascending: false })
          .limit(10),
      ])
      if (cancelled) return
      setVehicle(v as FleetStatusRow | null)
      setEvents((ev ?? []) as FleetEvent[])
      setTrips((tr ?? []) as Trip[])
    }
    load()
    const intId = setInterval(load, 5000)
    return () => {
      cancelled = true
      clearInterval(intId)
    }
  }, [id])

  if (!vehicle) {
    return (
      <PageShell title="Vehicul" subtitle="Se incarca...">
        <Card className="p-12 text-center text-textDim">
          {vehicle === null ? 'Vehiculul nu a fost gasit.' : 'Loading...'}
        </Card>
      </PageShell>
    )
  }

  return (
    <PageShell
      title={vehicle.plate}
      subtitle={`${vehicle.make ?? ''} ${vehicle.model ?? ''} ${vehicle.year ?? ''} · ${vehicle.driver_name ?? 'fara sofer'}`}
      actions={
        <Link
          href="/vehicles"
          className="flex items-center gap-2 rounded-lg border border-border/70 bg-surface/60 px-3 py-2 text-sm text-textMuted transition hover:border-cyan/40 hover:text-white"
        >
          <ArrowLeft size={14} /> Inapoi la flota
        </Link>
      }
    >
      {/* Status + GPS top row */}
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <StatusBadge status={vehicle.status} />
        <span className="text-[11px] text-textMuted">
          Ultim update:{' '}
          {vehicle.last_seen_at
            ? new Date(vehicle.last_seen_at).toLocaleString('ro-RO')
            : '—'}
        </span>
        {vehicle.lat != null && vehicle.lon != null && (
          <span className="ml-auto flex items-center gap-2 rounded-full border border-cyan/30 bg-cyan/5 px-3 py-1 font-mono text-[11px] tabular-nums text-cyan">
            <MapPin size={12} />
            {vehicle.lat.toFixed(5)}, {vehicle.lon.toFixed(5)}
          </span>
        )}
      </div>

      {/* KPI grid */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
        <StatCard
          label="VITEZA"
          value={(vehicle.speed_kmh ?? 0).toFixed(0)}
          unit="km/h"
          color="cyan"
          icon={<Gauge size={18} />}
        />
        <StatCard
          label="RPM"
          value={(vehicle.rpm ?? 0).toFixed(0)}
          color="cyan"
          icon={<Activity size={18} />}
        />
        <StatCard
          label="COOLANT"
          value={(vehicle.coolant ?? 0).toFixed(0)}
          unit="°C"
          color="warn"
          icon={<Thermometer size={18} />}
        />
        <StatCard
          label="BATERIE"
          value={(vehicle.battery ?? 0).toFixed(2)}
          unit="V"
          color="ok"
          icon={<Battery size={18} />}
        />
        <StatCard
          label="FUEL"
          value={(vehicle.fuel_pct ?? 0).toFixed(0)}
          unit="%"
          color="ok"
          icon={<Fuel size={18} />}
        />
        <StatCard
          label="THROTTLE"
          value={(vehicle.throttle ?? 0).toFixed(0)}
          unit="%"
          color="cyan"
          icon={<Activity size={18} />}
        />
      </div>

      {/* Two columns: events + trips */}
      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader
            title={`EVENIMENTE · ${events.length}`}
            subtitle="DTC, harsh brake / accel — ultimele 20"
            right={<AlertTriangle size={14} className="text-warn" />}
          />
          <div className="max-h-[420px] overflow-y-auto p-3">
            {events.length === 0 && (
              <p className="px-2 py-6 text-center text-xs text-textDim">
                Niciun eveniment.
              </p>
            )}
            <ul className="space-y-1.5">
              {events.map((e) => (
                <li
                  key={e.id}
                  className={`rounded-lg border p-3 text-sm ${
                    e.severity === 'critical'
                      ? 'border-danger/40 bg-danger/5'
                      : e.severity === 'warning'
                        ? 'border-warn/40 bg-warn/5'
                        : 'border-cyan/40 bg-cyan/5'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span
                      className={`font-display text-xs font-black tracking-wider ${
                        e.severity === 'critical'
                          ? 'text-danger'
                          : e.severity === 'warning'
                            ? 'text-warn'
                            : 'text-cyan'
                      }`}
                    >
                      {e.code ?? e.type.toUpperCase()}
                    </span>
                    <span className="font-mono text-[10px] text-textMuted">
                      {new Date(e.ts).toLocaleString('ro-RO')}
                    </span>
                  </div>
                  <p className="mt-1 text-white">{e.title}</p>
                  {e.description && (
                    <p className="mt-0.5 text-[11px] text-textMuted">
                      {e.description}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </Card>

        <Card>
          <CardHeader
            title={`TRASEE · ${trips.length}`}
            subtitle="ultimele 10 sesiuni inregistrate"
            right={<Route size={14} className="text-cyan" />}
          />
          <div className="max-h-[420px] overflow-y-auto p-3">
            {trips.length === 0 && (
              <p className="px-2 py-6 text-center text-xs text-textDim">
                Niciun traseu inregistrat.
              </p>
            )}
            <ul className="space-y-1.5">
              {trips.map((t) => (
                <li
                  key={t.id}
                  className="overflow-hidden rounded-lg border border-border/60 bg-surface/40 transition hover:border-cyan/60 hover:bg-surface/80"
                >
                  <Link href={`/trips/${t.id}`} className="block p-3">
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] text-textMuted">
                        {new Date(t.started_at).toLocaleString('ro-RO')}
                      </span>
                      <span className="rounded bg-cyan/15 px-2 py-0.5 font-display text-[10px] font-black tracking-wider text-cyan">
                        REPLAY →
                      </span>
                    </div>
                    <div className="mt-2 flex gap-5 text-sm">
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
                      <Stat
                        label="ECO"
                        value={`${t.eco_score ?? 0}`}
                        unit="/100"
                      />
                      <Stat
                        label="FUEL"
                        value={`${(t.fuel_l ?? 0).toFixed(1)}`}
                        unit="L"
                      />
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </Card>
      </div>
    </PageShell>
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
