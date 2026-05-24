'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { supabase, type FleetStatusRow } from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { StatCard } from '@/components/ui/Card'
import StatusBadge from '@/components/ui/StatusBadge'
import {
  Car,
  Search,
  ChevronRight,
  Gauge,
  Activity,
  Wifi,
  AlertTriangle,
} from 'lucide-react'

type StatusFilter = 'all' | 'driving' | 'idle' | 'alert' | 'offline'

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState<FleetStatusRow[]>([])
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<StatusFilter>('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const { data } = await supabase
        .from('fleet_status')
        .select('*')
        .order('plate', { ascending: true })
      if (!cancelled) {
        setVehicles((data ?? []) as FleetStatusRow[])
        setLoading(false)
      }
    }
    load()
    const id = setInterval(load, 5000)
    return () => {
      cancelled = true
      clearInterval(id)
    }
  }, [])

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim()
    return vehicles.filter((v) => {
      if (status !== 'all' && v.status !== status) return false
      if (!q) return true
      return (
        (v.plate ?? '').toLowerCase().includes(q) ||
        (v.driver_name ?? '').toLowerCase().includes(q) ||
        (v.make ?? '').toLowerCase().includes(q) ||
        (v.model ?? '').toLowerCase().includes(q) ||
        (v.vin ?? '').toLowerCase().includes(q)
      )
    })
  }, [vehicles, query, status])

  const counts = useMemo(() => {
    const c = { total: vehicles.length, driving: 0, idle: 0, alert: 0, offline: 0 }
    vehicles.forEach((v) => (c[v.status] = (c[v.status] ?? 0) + 1))
    return c
  }, [vehicles])

  return (
    <PageShell
      title="Vehicule"
      subtitle="Inventarul complet al flotei · click pe randul vehiculului pentru detalii live"
    >
      {/* Stats row */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-5">
        <StatCard
          label="TOTAL"
          value={counts.total}
          color="cyan"
          icon={<Car size={18} />}
        />
        <StatCard
          label="DRIVING"
          value={counts.driving}
          color="ok"
          icon={<Gauge size={18} />}
        />
        <StatCard
          label="IDLE"
          value={counts.idle}
          color="warn"
          icon={<Activity size={18} />}
        />
        <StatCard
          label="ALERT"
          value={counts.alert}
          color="danger"
          icon={<AlertTriangle size={18} />}
        />
        <StatCard
          label="OFFLINE"
          value={counts.offline}
          color="cyan"
          icon={<Wifi size={18} />}
        />
      </div>

      {/* Filters */}
      <div className="mb-4 flex items-center gap-3">
        <div className="relative flex-1 max-w-md">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-textDim"
          />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="cauta plate, sofer, model, VIN..."
            className="w-full rounded-lg border border-border/70 bg-surface/60 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none"
          />
        </div>
        <div className="flex items-center gap-1 rounded-lg border border-border/70 bg-surface/60 p-1">
          {(['all', 'driving', 'idle', 'alert', 'offline'] as StatusFilter[]).map(
            (s) => (
              <button
                key={s}
                onClick={() => setStatus(s)}
                className={`rounded-md px-3 py-1.5 font-display text-[10px] font-bold tracking-widest transition ${
                  status === s
                    ? 'bg-cyan/15 text-cyan'
                    : 'text-textMuted hover:text-white'
                }`}
              >
                {s === 'all' ? 'TOATE' : s.toUpperCase()}
              </button>
            ),
          )}
        </div>
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-2xl border border-border/60 bg-surface/40 backdrop-blur-md">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border/60 bg-bg/40 text-left">
              <Th>Vehicul</Th>
              <Th>Sofer</Th>
              <Th>Status</Th>
              <Th align="right">Viteza</Th>
              <Th align="right">RPM</Th>
              <Th align="right">Coolant</Th>
              <Th align="right">Bat</Th>
              <Th align="right">Fuel</Th>
              <Th>Ultim update</Th>
              <Th align="right"> </Th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={10} className="px-5 py-12 text-center text-textDim">
                  Se incarca flota...
                </td>
              </tr>
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={10} className="px-5 py-12 text-center text-textDim">
                  Niciun vehicul gasit pentru filtrul curent.
                </td>
              </tr>
            ) : (
              filtered.map((v) => (
                <tr
                  key={v.vehicle_id}
                  className="border-b border-border/40 transition hover:bg-cyan/5"
                >
                  <Td>
                    <Link
                      href={`/vehicles/${v.vehicle_id}`}
                      className="flex items-center gap-3"
                    >
                      <div
                        className="h-7 w-7 shrink-0 rounded-lg"
                        style={{
                          background: v.color ?? '#22d3ee',
                          boxShadow: `0 0 16px -2px ${v.color ?? '#22d3ee'}80`,
                        }}
                      />
                      <div className="min-w-0">
                        <div className="font-display text-sm font-bold tracking-wider text-white">
                          {v.plate}
                        </div>
                        <div className="truncate text-[11px] text-textMuted">
                          {v.make} {v.model} {v.year ?? ''}
                        </div>
                      </div>
                    </Link>
                  </Td>
                  <Td>{v.driver_name ?? '—'}</Td>
                  <Td>
                    <StatusBadge status={v.status} />
                  </Td>
                  <Td align="right" mono>
                    {(v.speed_kmh ?? 0).toFixed(0)}
                    <span className="ml-0.5 text-[10px] text-textDim">km/h</span>
                  </Td>
                  <Td align="right" mono>
                    {(v.rpm ?? 0).toFixed(0)}
                  </Td>
                  <Td align="right" mono>
                    {(v.coolant ?? 0).toFixed(0)}
                    <span className="ml-0.5 text-[10px] text-textDim">°C</span>
                  </Td>
                  <Td align="right" mono>
                    {(v.battery ?? 0).toFixed(1)}
                    <span className="ml-0.5 text-[10px] text-textDim">V</span>
                  </Td>
                  <Td align="right" mono>
                    {(v.fuel_pct ?? 0).toFixed(0)}
                    <span className="ml-0.5 text-[10px] text-textDim">%</span>
                  </Td>
                  <Td>
                    <span className="text-[11px] text-textMuted">
                      {v.last_seen_at
                        ? new Date(v.last_seen_at).toLocaleTimeString('ro-RO')
                        : '—'}
                    </span>
                  </Td>
                  <Td align="right">
                    <Link
                      href={`/vehicles/${v.vehicle_id}`}
                      className="inline-flex items-center gap-1 text-cyan opacity-60 transition hover:opacity-100"
                    >
                      <ChevronRight size={16} />
                    </Link>
                  </Td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </PageShell>
  )
}

function Th({
  children,
  align = 'left',
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
}) {
  return (
    <th
      className={`px-5 py-3 font-display text-[10px] font-bold uppercase tracking-widest text-textMuted ${
        align === 'right' ? 'text-right' : ''
      }`}
    >
      {children}
    </th>
  )
}

function Td({
  children,
  align = 'left',
  mono,
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
  mono?: boolean
}) {
  return (
    <td
      className={`px-5 py-3 text-sm text-white ${
        align === 'right' ? 'text-right' : ''
      } ${mono ? 'font-mono tabular-nums' : ''}`}
    >
      {children}
    </td>
  )
}
