'use client'

import { useEffect, useMemo, useState } from 'react'
import { supabase, type Trip, type FleetStatusRow } from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { Card, CardHeader, StatCard } from '@/components/ui/Card'
import { Users, Award, Route, Gauge, Search } from 'lucide-react'

type DriverStats = {
  name: string
  vehicles: FleetStatusRow[]
  totalKm: number
  totalTrips: number
  avgEco: number
  maxSpeed: number
  totalFuel: number
}

export default function DriversPage() {
  const [vehicles, setVehicles] = useState<FleetStatusRow[]>([])
  const [trips, setTrips] = useState<Trip[]>([])
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const [{ data: v }, { data: t }] = await Promise.all([
        supabase.from('fleet_status').select('*'),
        supabase
          .from('trips')
          .select('*')
          .order('started_at', { ascending: false })
          .limit(500),
      ])
      if (!cancelled) {
        setVehicles((v ?? []) as FleetStatusRow[])
        setTrips((t ?? []) as Trip[])
        setLoading(false)
      }
    }
    load()
  }, [])

  // Agregam dupa numele soferului (din vehicles si trips)
  const drivers = useMemo<DriverStats[]>(() => {
    const map = new Map<string, DriverStats>()
    vehicles.forEach((v) => {
      const name = v.driver_name?.trim() || 'Nealocat'
      if (!map.has(name)) {
        map.set(name, {
          name,
          vehicles: [],
          totalKm: 0,
          totalTrips: 0,
          avgEco: 0,
          maxSpeed: 0,
          totalFuel: 0,
        })
      }
      map.get(name)!.vehicles.push(v)
    })

    trips.forEach((t) => {
      const name = t.driver_name?.trim() || 'Nealocat'
      const d = map.get(name)
      if (!d) return
      d.totalKm += t.distance_km ?? 0
      d.totalTrips += 1
      d.avgEco += t.eco_score ?? 0
      d.maxSpeed = Math.max(d.maxSpeed, t.max_speed_kmh ?? 0)
      d.totalFuel += t.fuel_l ?? 0
    })

    return Array.from(map.values())
      .map((d) => ({
        ...d,
        avgEco: d.totalTrips > 0 ? Math.round(d.avgEco / d.totalTrips) : 0,
      }))
      .sort((a, b) => b.avgEco - a.avgEco)
  }, [vehicles, trips])

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim()
    if (!q) return drivers
    return drivers.filter((d) => d.name.toLowerCase().includes(q))
  }, [drivers, query])

  const totals = useMemo(() => {
    const totalKm = drivers.reduce((s, d) => s + d.totalKm, 0)
    const totalTrips = drivers.reduce((s, d) => s + d.totalTrips, 0)
    const avgEco =
      drivers.length > 0
        ? Math.round(
            drivers.reduce((s, d) => s + d.avgEco, 0) / drivers.length,
          )
        : 0
    return { totalKm, totalTrips, avgEco, count: drivers.length }
  }, [drivers])

  return (
    <PageShell
      title="Soferi"
      subtitle="Performanta soferi flotei · scor eco agregat din toate sesiunile inregistrate"
    >
      {/* Stats */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatCard
          label="SOFERI"
          value={totals.count}
          color="cyan"
          icon={<Users size={18} />}
        />
        <StatCard
          label="ECO MEDIU"
          value={totals.avgEco}
          unit="/100"
          color={totals.avgEco >= 75 ? 'ok' : totals.avgEco >= 50 ? 'warn' : 'danger'}
          icon={<Award size={18} />}
        />
        <StatCard
          label="TRASEE"
          value={totals.totalTrips}
          color="cyan"
          icon={<Route size={18} />}
        />
        <StatCard
          label="DISTANTA"
          value={totals.totalKm.toFixed(0)}
          unit="km"
          color="cyan"
          icon={<Gauge size={18} />}
        />
      </div>

      {/* Search */}
      <div className="mb-4 max-w-md">
        <div className="relative">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-textDim"
          />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="cauta sofer..."
            className="w-full rounded-lg border border-border/70 bg-surface/60 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none"
          />
        </div>
      </div>

      {/* Drivers grid */}
      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
        {loading ? (
          <Card className="col-span-full p-12 text-center text-textDim">
            Se incarca soferii...
          </Card>
        ) : filtered.length === 0 ? (
          <Card className="col-span-full p-12 text-center text-textDim">
            Niciun sofer.
          </Card>
        ) : (
          filtered.map((d, idx) => <DriverCard key={d.name} d={d} rank={idx + 1} />)
        )}
      </div>

      {/* Top 3 leaderboard */}
      {filtered.length >= 3 && (
        <Card className="mt-8">
          <CardHeader
            title="TOP 3 ECO MASTERS"
            subtitle="cei mai eficienti soferi · scor eco mediu"
            right={<Award size={14} className="text-warn" />}
          />
          <div className="grid gap-3 p-5 md:grid-cols-3">
            {filtered.slice(0, 3).map((d, idx) => (
              <div
                key={d.name}
                className={`rounded-xl border p-4 ${
                  idx === 0
                    ? 'border-warn/40 bg-warn/5'
                    : idx === 1
                      ? 'border-textMuted/40 bg-surface/40'
                      : 'border-cyan-deep/40 bg-cyan/5'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`grid h-10 w-10 place-items-center rounded-full font-display text-base font-black ${
                      idx === 0
                        ? 'bg-warn text-bg'
                        : idx === 1
                          ? 'bg-textMuted text-bg'
                          : 'bg-cyan-deep text-white'
                    }`}
                  >
                    {idx + 1}
                  </div>
                  <div>
                    <p className="font-display text-sm font-black text-white">
                      {d.name}
                    </p>
                    <p className="text-[10px] text-textMuted">
                      {d.totalTrips} trasee · {d.totalKm.toFixed(0)} km
                    </p>
                  </div>
                  <span className="ml-auto font-display text-2xl font-black text-cyan">
                    {d.avgEco}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}
    </PageShell>
  )
}

function DriverCard({ d, rank }: { d: DriverStats; rank: number }) {
  const ecoColor =
    d.avgEco >= 75 ? 'text-ok' : d.avgEco >= 50 ? 'text-warn' : 'text-danger'
  return (
    <Card className="p-4 transition hover:border-cyan/40 hover:shadow-[0_0_24px_-8px_rgba(0,212,255,0.4)]">
      <div className="flex items-center gap-3">
        <div className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-gradient-to-br from-cyan to-cyan-deep font-display text-base font-black text-bg">
          {d.name
            .split(/\s+/)
            .map((p) => p[0])
            .filter(Boolean)
            .slice(0, 2)
            .join('')
            .toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-base font-black text-white">
            {d.name}
          </p>
          <p className="text-[11px] text-textMuted">
            #{rank} · {d.vehicles.length}{' '}
            {d.vehicles.length === 1 ? 'vehicul' : 'vehicule'}
          </p>
        </div>
        <div className="text-right">
          <p className={`font-display text-2xl font-black ${ecoColor}`}>
            {d.avgEco}
          </p>
          <p className="text-[9px] tracking-widest text-textDim">ECO</p>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-3 gap-2 border-t border-border/60 pt-3 text-center">
        <Mini label="KM" value={d.totalKm.toFixed(0)} />
        <Mini label="TRASEE" value={d.totalTrips.toString()} />
        <Mini
          label="MAX"
          value={d.maxSpeed.toFixed(0)}
          unit="km/h"
        />
      </div>
    </Card>
  )
}

function Mini({
  label,
  value,
  unit,
}: {
  label: string
  value: string
  unit?: string
}) {
  return (
    <div>
      <p className="font-display text-sm font-black text-white">
        {value}
        {unit && (
          <span className="ml-0.5 text-[9px] font-medium text-textMuted">
            {unit}
          </span>
        )}
      </p>
      <p className="text-[9px] tracking-widest text-textDim">{label}</p>
    </div>
  )
}
