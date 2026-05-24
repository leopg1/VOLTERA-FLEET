'use client'

import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'next/navigation'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { supabase, TelemetrySample, Trip, Vehicle } from '@/lib/supabase'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend,
} from 'recharts'
import { ArrowLeft, Play, Pause } from 'lucide-react'

const TripReplayMap = dynamic(() => import('@/components/TripReplayMap'), {
  ssr: false,
})

export default function TripPage() {
  const { id } = useParams<{ id: string }>()
  const [trip, setTrip] = useState<Trip | null>(null)
  const [vehicle, setVehicle] = useState<Vehicle | null>(null)
  const [samples, setSamples] = useState<TelemetrySample[]>([])
  const [cursor, setCursor] = useState(0)
  const [playing, setPlaying] = useState(false)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const { data: t } = await supabase
        .from('trips')
        .select('*')
        .eq('id', id)
        .maybeSingle()
      if (cancelled || !t) return
      setTrip(t as Trip)

      const [{ data: v }, { data: ss }] = await Promise.all([
        supabase
          .from('vehicles')
          .select('*')
          .eq('id', (t as Trip).vehicle_id)
          .maybeSingle(),
        supabase
          .from('telemetry_samples')
          .select('*')
          .eq('trip_id', id)
          .order('ts', { ascending: true })
          .limit(5000),
      ])
      if (cancelled) return
      setVehicle(v as Vehicle | null)
      setSamples((ss ?? []) as TelemetrySample[])
    }
    load()
    return () => {
      cancelled = true
    }
  }, [id])

  // Playback
  useEffect(() => {
    if (!playing || samples.length === 0) return
    const it = setInterval(() => {
      setCursor((c) => {
        if (c >= samples.length - 1) {
          setPlaying(false)
          return c
        }
        return c + 1
      })
    }, 80)
    return () => clearInterval(it)
  }, [playing, samples.length])

  const chartData = useMemo(
    () =>
      samples.map((s, i) => ({
        i,
        t: new Date(s.ts).getTime(),
        speed: s.speed_kmh ?? 0,
        rpm: (s.rpm ?? 0) / 100,
        throttle: s.throttle ?? 0,
      })),
    [samples],
  )

  const current = samples[cursor] ?? null

  return (
    <main className="relative h-screen w-screen overflow-hidden bg-bg text-white">
      <header className="pointer-events-auto fixed left-0 right-0 top-0 z-20 flex items-center gap-4 border-b border-border bg-surface/85 px-5 py-3 backdrop-blur">
        <Link
          href="/"
          className="rounded-md border border-border bg-surfaceHi p-2 text-textMuted hover:text-white"
        >
          <ArrowLeft size={16} />
        </Link>
        <div>
          <h1 className="font-display text-lg font-black tracking-wider text-white">
            TRIP REPLAY
          </h1>
          <p className="text-xs text-textMuted">
            {vehicle?.plate ?? '...'} · {vehicle?.driver_name ?? '—'} ·{' '}
            {trip ? new Date(trip.started_at).toLocaleString('ro-RO') : '...'}
          </p>
        </div>
        <div className="ml-auto flex gap-3 text-xs">
          <Stat label="DIST" value={`${(trip?.distance_km ?? 0).toFixed(1)} km`} />
          <Stat label="MAX" value={`${(trip?.max_speed_kmh ?? 0).toFixed(0)} km/h`} />
          <Stat label="RPM" value={`${(trip?.max_rpm ?? 0).toFixed(0)}`} />
          <Stat label="ECO" value={`${trip?.eco_score ?? 0}`} />
        </div>
      </header>

      {/* Map */}
      <div className="absolute inset-0 pt-[60px]">
        <TripReplayMap samples={samples} cursorIndex={cursor} />
      </div>

      {/* Bottom panel: chart + slider */}
      <section className="pointer-events-auto fixed bottom-0 left-0 right-0 z-10 border-t border-border bg-surface/95 p-4 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setPlaying((p) => !p)}
            className="rounded-md bg-cyan px-3 py-2 text-black hover:bg-cyan/80"
          >
            {playing ? <Pause size={16} /> : <Play size={16} />}
          </button>
          <input
            type="range"
            min={0}
            max={Math.max(0, samples.length - 1)}
            value={cursor}
            onChange={(e) => setCursor(Number(e.target.value))}
            className="flex-1 accent-cyan"
          />
          <div className="w-44 text-right">
            <p className="font-display text-sm font-bold text-white">
              {current
                ? new Date(current.ts).toLocaleTimeString('ro-RO')
                : '--:--:--'}
            </p>
            <p className="text-[10px] text-textMuted">
              {cursor + 1} / {samples.length}
            </p>
          </div>
        </div>

        <div className="mt-3 grid grid-cols-4 gap-3">
          <LiveCell label="SPEED" value={current?.speed_kmh ?? 0} unit="km/h" />
          <LiveCell label="RPM" value={current?.rpm ?? 0} unit="rpm" decimals={0} />
          <LiveCell label="THR" value={current?.throttle ?? 0} unit="%" decimals={0} />
          <LiveCell label="ECT" value={current?.coolant ?? 0} unit="°C" />
        </div>

        <div className="mt-3 h-32">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1F2937" />
              <XAxis dataKey="i" stroke="#4A5260" hide />
              <YAxis stroke="#4A5260" tick={{ fontSize: 10 }} width={28} />
              <Tooltip
                contentStyle={{
                  background: '#0D1117',
                  border: '1px solid #00D4FF55',
                  borderRadius: 8,
                  fontSize: 11,
                }}
              />
              <Legend wrapperStyle={{ fontSize: 10 }} />
              <Line type="monotone" dataKey="speed" stroke="#00D4FF" dot={false} strokeWidth={2} />
              <Line type="monotone" dataKey="rpm" stroke="#FFC400" dot={false} strokeWidth={2} name="rpm/100" />
              <Line type="monotone" dataKey="throttle" stroke="#00E676" dot={false} strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </section>
    </main>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-border bg-surface/60 px-3 py-1.5">
      <p className="text-[9px] uppercase tracking-widest text-textDim">{label}</p>
      <p className="font-display text-sm font-bold text-white">{value}</p>
    </div>
  )
}

function LiveCell({
  label, value, unit, decimals = 1,
}: { label: string; value: number; unit: string; decimals?: number }) {
  return (
    <div className="rounded-lg border border-border bg-surface/50 px-3 py-2">
      <p className="text-[9px] uppercase tracking-widest text-textMuted">{label}</p>
      <p className="font-display text-xl font-black text-white">
        {value.toFixed(decimals)}
        <span className="ml-1 text-[10px] text-textMuted">{unit}</span>
      </p>
    </div>
  )
}
