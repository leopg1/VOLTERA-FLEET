'use client'

import { useEffect, useMemo, useState } from 'react'
import {
  supabase,
  type Trip,
  type FleetEvent,
  type FleetStatusRow,
} from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { Card, CardHeader, StatCard } from '@/components/ui/Card'
import {
  BarChart3,
  Gauge,
  Fuel,
  CloudFog,
  TrendingUp,
  Award,
} from 'lucide-react'
import {
  ResponsiveContainer,
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from 'recharts'

export default function AnalyticsPage() {
  const [trips, setTrips] = useState<Trip[]>([])
  const [events, setEvents] = useState<FleetEvent[]>([])
  const [vehicles, setVehicles] = useState<FleetStatusRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const [{ data: t }, { data: e }, { data: v }] = await Promise.all([
        supabase
          .from('trips')
          .select('*')
          .order('started_at', { ascending: false })
          .limit(200),
        supabase
          .from('events')
          .select('*')
          .order('ts', { ascending: false })
          .limit(300),
        supabase.from('fleet_status').select('*'),
      ])
      if (!cancelled) {
        setTrips((t ?? []) as Trip[])
        setEvents((e ?? []) as FleetEvent[])
        setVehicles((v ?? []) as FleetStatusRow[])
        setLoading(false)
      }
    }
    load()
  }, [])

  // Distanta zilnica (ultimele 14 zile)
  const distancePerDay = useMemo(() => {
    const days: Record<string, number> = {}
    const now = new Date()
    for (let i = 13; i >= 0; i--) {
      const d = new Date(now)
      d.setDate(d.getDate() - i)
      days[d.toISOString().slice(0, 10)] = 0
    }
    trips.forEach((t) => {
      const key = t.started_at.slice(0, 10)
      if (key in days) days[key] += t.distance_km ?? 0
    })
    return Object.entries(days).map(([day, km]) => ({
      day: day.slice(5),
      km: Math.round(km * 10) / 10,
    }))
  }, [trips])

  // Distributie evenimente pe severitate
  const severityDistribution = useMemo(() => {
    const c = { critical: 0, warning: 0, info: 0 }
    events.forEach((e) => c[e.severity]++)
    return [
      { name: 'Critical', value: c.critical, color: '#FF1744' },
      { name: 'Warning', value: c.warning, color: '#FFC400' },
      { name: 'Info', value: c.info, color: '#00D4FF' },
    ]
  }, [events])

  // Top 5 soferi dupa eco score
  const topDrivers = useMemo(() => {
    const map = new Map<string, { count: number; total: number }>()
    trips.forEach((t) => {
      const n = t.driver_name?.trim() || 'Nealocat'
      if (!map.has(n)) map.set(n, { count: 0, total: 0 })
      const x = map.get(n)!
      x.count++
      x.total += t.eco_score ?? 0
    })
    return Array.from(map.entries())
      .map(([name, { count, total }]) => ({
        name,
        eco: count > 0 ? Math.round(total / count) : 0,
        trips: count,
      }))
      .filter((d) => d.trips >= 1)
      .sort((a, b) => b.eco - a.eco)
      .slice(0, 5)
  }, [trips])

  // Total agregate
  const totals = useMemo(() => {
    const totalKm = trips.reduce((s, t) => s + (t.distance_km ?? 0), 0)
    const totalFuel = trips.reduce((s, t) => s + (t.fuel_l ?? 0), 0)
    const totalCo2 = totalFuel * 2.31
    const avgEco =
      trips.length > 0
        ? Math.round(
            trips.reduce((s, t) => s + (t.eco_score ?? 0), 0) / trips.length,
          )
        : 0
    return { totalKm, totalFuel, totalCo2, avgEco }
  }, [trips])

  return (
    <PageShell
      title="Analytics"
      subtitle="Statistici agregate ale flotei · 200 trasee recente · 300 evenimente"
    >
      {/* KPI grid */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatCard
          label="DISTANTA"
          value={totals.totalKm.toFixed(0)}
          unit="km"
          color="cyan"
          icon={<Gauge size={18} />}
        />
        <StatCard
          label="COMBUSTIBIL"
          value={totals.totalFuel.toFixed(1)}
          unit="L"
          color="warn"
          icon={<Fuel size={18} />}
        />
        <StatCard
          label="CO₂"
          value={totals.totalCo2.toFixed(1)}
          unit="kg"
          color="ok"
          icon={<CloudFog size={18} />}
        />
        <StatCard
          label="ECO MEDIU"
          value={totals.avgEco}
          unit="/100"
          color={
            totals.avgEco >= 75 ? 'ok' : totals.avgEco >= 50 ? 'warn' : 'danger'
          }
          icon={<Award size={18} />}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Distanta zilnica */}
        <Card>
          <CardHeader
            title="DISTANTA ZILNICA · 14 ZILE"
            subtitle="km parcursi cumulativ pe flota"
            right={<TrendingUp size={14} className="text-cyan" />}
          />
          <div className="p-3" style={{ height: 280 }}>
            {loading ? (
              <Loading />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={distancePerDay}
                  margin={{ top: 10, right: 16, bottom: 4, left: 0 }}
                >
                  <CartesianGrid stroke="#1F2937" strokeDasharray="3 3" />
                  <XAxis
                    dataKey="day"
                    stroke="#8892A4"
                    fontSize={10}
                    fontFamily="Rajdhani"
                  />
                  <YAxis stroke="#8892A4" fontSize={10} />
                  <Tooltip
                    contentStyle={{
                      background: '#0D1117',
                      border: '1px solid #00D4FF55',
                      borderRadius: 12,
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                    }}
                    labelStyle={{ color: '#fff', fontWeight: 700 }}
                  />
                  <Bar
                    dataKey="km"
                    fill="#00D4FF"
                    radius={[4, 4, 0, 0]}
                    name="km"
                  />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        {/* Distributie alerte pe severitate */}
        <Card>
          <CardHeader
            title="ALERTE · DISTRIBUTIE SEVERITATE"
            subtitle="critical / warning / info din ultimele 300"
            right={<BarChart3 size={14} className="text-cyan" />}
          />
          <div className="p-3" style={{ height: 280 }}>
            {loading ? (
              <Loading />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={severityDistribution}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={90}
                    paddingAngle={3}
                  >
                    {severityDistribution.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      background: '#0D1117',
                      border: '1px solid #00D4FF55',
                      borderRadius: 12,
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                    }}
                  />
                  <Legend
                    wrapperStyle={{ fontFamily: 'Rajdhani', fontSize: 11 }}
                  />
                </PieChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        {/* Top 5 soferi */}
        <Card className="lg:col-span-2">
          <CardHeader
            title="TOP 5 ECO DRIVERS"
            subtitle="cei mai eficienti soferi · scor eco mediu pe sesiune"
            right={<Award size={14} className="text-warn" />}
          />
          <div className="p-3" style={{ height: 260 }}>
            {loading ? (
              <Loading />
            ) : topDrivers.length === 0 ? (
              <p className="grid h-full place-items-center text-textDim">
                Niciun sofer cu sesiuni inca.
              </p>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={topDrivers}
                  layout="vertical"
                  margin={{ top: 10, right: 16, bottom: 4, left: 80 }}
                >
                  <CartesianGrid stroke="#1F2937" strokeDasharray="3 3" />
                  <XAxis
                    type="number"
                    stroke="#8892A4"
                    fontSize={10}
                    domain={[0, 100]}
                  />
                  <YAxis
                    dataKey="name"
                    type="category"
                    stroke="#8892A4"
                    fontSize={11}
                    fontFamily="Rajdhani"
                    width={80}
                  />
                  <Tooltip
                    contentStyle={{
                      background: '#0D1117',
                      border: '1px solid #00D4FF55',
                      borderRadius: 12,
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                    }}
                  />
                  <Bar
                    dataKey="eco"
                    fill="#00E676"
                    radius={[0, 4, 4, 0]}
                    name="Eco score"
                  />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>
      </div>
    </PageShell>
  )
}

function Loading() {
  return (
    <div className="grid h-full place-items-center text-textDim">
      Se calculeaza...
    </div>
  )
}
