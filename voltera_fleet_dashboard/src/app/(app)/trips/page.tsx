'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { supabase, type Trip } from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { StatCard } from '@/components/ui/Card'
import { Route, Search, ChevronRight, Gauge, Fuel, Award } from 'lucide-react'

type EnrichedTrip = Trip & { plate?: string; make?: string; model?: string }

export default function TripsPage() {
  const [trips, setTrips] = useState<EnrichedTrip[]>([])
  const [query, setQuery] = useState('')
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | 'all'>('7d')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const [{ data: t }, { data: v }] = await Promise.all([
        supabase
          .from('trips')
          .select('*')
          .order('started_at', { ascending: false })
          .limit(500),
        supabase.from('fleet_status').select('vehicle_id, plate, make, model'),
      ])
      if (cancelled) return
      const vMap = new Map<string, { plate: string; make: string; model: string }>()
      ;((v ?? []) as Array<{
        vehicle_id: string
        plate: string
        make: string
        model: string
      }>).forEach((row) =>
        vMap.set(row.vehicle_id, {
          plate: row.plate,
          make: row.make,
          model: row.model,
        }),
      )
      const enriched = ((t ?? []) as Trip[]).map((tr) => ({
        ...tr,
        ...vMap.get(tr.vehicle_id),
      }))
      setTrips(enriched)
      setLoading(false)
    }
    load()
  }, [])

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim()
    const now = Date.now()
    const cutoff =
      period === '24h'
        ? now - 24 * 3600 * 1000
        : period === '7d'
          ? now - 7 * 24 * 3600 * 1000
          : period === '30d'
            ? now - 30 * 24 * 3600 * 1000
            : 0
    return trips.filter((t) => {
      if (cutoff > 0 && new Date(t.started_at).getTime() < cutoff) return false
      if (!q) return true
      return (
        (t.plate ?? '').toLowerCase().includes(q) ||
        (t.driver_name ?? '').toLowerCase().includes(q) ||
        (t.make ?? '').toLowerCase().includes(q) ||
        (t.model ?? '').toLowerCase().includes(q)
      )
    })
  }, [trips, query, period])

  const stats = useMemo(() => {
    const totalKm = filtered.reduce((s, t) => s + (t.distance_km ?? 0), 0)
    const totalFuel = filtered.reduce((s, t) => s + (t.fuel_l ?? 0), 0)
    const avgEco =
      filtered.length > 0
        ? Math.round(
            filtered.reduce((s, t) => s + (t.eco_score ?? 0), 0) /
              filtered.length,
          )
        : 0
    return { totalKm, totalFuel, avgEco, count: filtered.length }
  }, [filtered])

  return (
    <PageShell
      title="Trasee"
      subtitle="Istoricul drumurilor inregistrate · click pe traseu pentru replay pe harta"
    >
      {/* Stats */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatCard
          label="TOTAL TRASEE"
          value={stats.count}
          color="cyan"
          icon={<Route size={18} />}
        />
        <StatCard
          label="DISTANTA"
          value={stats.totalKm.toFixed(0)}
          unit="km"
          color="cyan"
          icon={<Gauge size={18} />}
        />
        <StatCard
          label="COMBUSTIBIL"
          value={stats.totalFuel.toFixed(1)}
          unit="L"
          color="warn"
          icon={<Fuel size={18} />}
        />
        <StatCard
          label="ECO MEDIU"
          value={stats.avgEco}
          unit="/100"
          color={
            stats.avgEco >= 75 ? 'ok' : stats.avgEco >= 50 ? 'warn' : 'danger'
          }
          icon={<Award size={18} />}
        />
      </div>

      {/* Filters */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 max-w-md">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-textDim"
          />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="cauta vehicul / sofer..."
            className="w-full rounded-lg border border-border/70 bg-surface/60 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none"
          />
        </div>
        <div className="flex items-center gap-1 rounded-lg border border-border/70 bg-surface/60 p-1">
          {(['24h', '7d', '30d', 'all'] as const).map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`rounded-md px-3 py-1.5 font-display text-[10px] font-bold tracking-widest transition ${
                period === p
                  ? 'bg-cyan/15 text-cyan'
                  : 'text-textMuted hover:text-white'
              }`}
            >
              {p === 'all' ? 'TOATE' : p.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-2xl border border-border/60 bg-surface/40 backdrop-blur-md">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border/60 bg-bg/40 text-left">
              <Th>Data</Th>
              <Th>Vehicul</Th>
              <Th>Sofer</Th>
              <Th align="right">Distanta</Th>
              <Th align="right">Max</Th>
              <Th align="right">Combustibil</Th>
              <Th align="right">Eco</Th>
              <Th align="right">Status</Th>
              <Th align="right">{' '}</Th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={9} className="px-5 py-12 text-center text-textDim">
                  Se incarca traseele...
                </td>
              </tr>
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-5 py-12 text-center text-textDim">
                  Niciun traseu pentru perioada / filtrul curent.
                </td>
              </tr>
            ) : (
              filtered.map((t) => {
                const ecoColor =
                  (t.eco_score ?? 0) >= 75
                    ? 'text-ok'
                    : (t.eco_score ?? 0) >= 50
                      ? 'text-warn'
                      : 'text-danger'
                return (
                  <tr
                    key={t.id}
                    className="border-b border-border/40 transition hover:bg-cyan/5"
                  >
                    <Td>
                      <Link href={`/trips/${t.id}`}>
                        <div className="font-display text-xs font-bold text-white">
                          {new Date(t.started_at).toLocaleDateString('ro-RO')}
                        </div>
                        <div className="text-[10px] text-textMuted">
                          {new Date(t.started_at).toLocaleTimeString('ro-RO')}
                        </div>
                      </Link>
                    </Td>
                    <Td>
                      <div className="font-display text-sm font-bold tracking-wider text-white">
                        {t.plate ?? '—'}
                      </div>
                      <div className="text-[10px] text-textMuted">
                        {t.make} {t.model}
                      </div>
                    </Td>
                    <Td>{t.driver_name ?? '—'}</Td>
                    <Td align="right" mono>
                      {(t.distance_km ?? 0).toFixed(1)}
                      <span className="ml-0.5 text-[10px] text-textDim">km</span>
                    </Td>
                    <Td align="right" mono>
                      {(t.max_speed_kmh ?? 0).toFixed(0)}
                      <span className="ml-0.5 text-[10px] text-textDim">
                        km/h
                      </span>
                    </Td>
                    <Td align="right" mono>
                      {(t.fuel_l ?? 0).toFixed(1)}
                      <span className="ml-0.5 text-[10px] text-textDim">L</span>
                    </Td>
                    <Td align="right">
                      <span
                        className={`font-display text-base font-black ${ecoColor}`}
                      >
                        {t.eco_score ?? 0}
                      </span>
                    </Td>
                    <Td align="right">
                      <span
                        className={`rounded-full border px-2 py-0.5 font-display text-[10px] font-bold tracking-widest ${
                          t.ended_at
                            ? 'border-textMuted/40 text-textMuted'
                            : 'border-ok/40 bg-ok/10 text-ok'
                        }`}
                      >
                        {t.ended_at ? 'FINALIZAT' : 'LIVE'}
                      </span>
                    </Td>
                    <Td align="right">
                      <Link
                        href={`/trips/${t.id}`}
                        className="inline-flex items-center gap-1 rounded-md bg-cyan/15 px-2 py-1 font-display text-[10px] font-black tracking-wider text-cyan transition hover:bg-cyan/25"
                      >
                        REPLAY <ChevronRight size={12} />
                      </Link>
                    </Td>
                  </tr>
                )
              })
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
