'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { supabase, type FleetEvent, type FleetStatusRow } from '@/lib/supabase'
import PageShell from '@/components/ui/PageShell'
import { StatCard } from '@/components/ui/Card'
import AIDtcExplainer from '@/components/AIDtcExplainer'
import {
  AlertOctagon,
  AlertTriangle,
  Info,
  Search,
  Filter,
  CheckCircle2,
} from 'lucide-react'

type SeverityFilter = 'all' | 'critical' | 'warning' | 'info'
type StateFilter = 'all' | 'unresolved' | 'resolved'

type EnrichedEvent = FleetEvent & {
  plate?: string
  driver_name?: string
  make?: string
  model?: string
}

export default function AlertsPage() {
  const [events, setEvents] = useState<EnrichedEvent[]>([])
  const [vehicles, setVehicles] = useState<Map<string, FleetStatusRow>>(
    new Map(),
  )
  const [query, setQuery] = useState('')
  const [severity, setSeverity] = useState<SeverityFilter>('all')
  const [state, setState] = useState<StateFilter>('unresolved')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const [{ data: ev }, { data: v }] = await Promise.all([
        supabase
          .from('events')
          .select('*')
          .order('ts', { ascending: false })
          .limit(300),
        supabase.from('fleet_status').select('*'),
      ])
      if (cancelled) return
      const vMap = new Map<string, FleetStatusRow>()
      ;((v ?? []) as FleetStatusRow[]).forEach((row) =>
        vMap.set(row.vehicle_id, row),
      )
      const enriched = ((ev ?? []) as FleetEvent[]).map((e) => {
        const veh = vMap.get(e.vehicle_id)
        return {
          ...e,
          plate: veh?.plate,
          driver_name: veh?.driver_name ?? undefined,
          make: veh?.make ?? undefined,
          model: veh?.model ?? undefined,
        }
      })
      setEvents(enriched)
      setVehicles(vMap)
      setLoading(false)
    }
    load()

    // Realtime: orice event nou apare instant
    const channel = supabase
      .channel('alerts-page')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'events' },
        () => load(),
      )
      .subscribe()

    return () => {
      cancelled = true
      supabase.removeChannel(channel)
    }
  }, [])

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim()
    return events.filter((e) => {
      if (severity !== 'all' && e.severity !== severity) return false
      if (state === 'unresolved' && e.resolved_at) return false
      if (state === 'resolved' && !e.resolved_at) return false
      if (!q) return true
      return (
        (e.code ?? '').toLowerCase().includes(q) ||
        (e.title ?? '').toLowerCase().includes(q) ||
        (e.type ?? '').toLowerCase().includes(q) ||
        (e.plate ?? '').toLowerCase().includes(q) ||
        (e.driver_name ?? '').toLowerCase().includes(q)
      )
    })
  }, [events, query, severity, state])

  const stats = useMemo(() => {
    const c = { total: 0, critical: 0, warning: 0, info: 0, resolved: 0 }
    events.forEach((e) => {
      c.total++
      c[e.severity]++
      if (e.resolved_at) c.resolved++
    })
    return c
  }, [events])

  async function markResolved(id: string) {
    await supabase
      .from('events')
      .update({ resolved_at: new Date().toISOString() })
      .eq('id', id)
    setEvents((prev) =>
      prev.map((e) =>
        e.id === id ? { ...e, resolved_at: new Date().toISOString() } : e,
      ),
    )
  }

  return (
    <PageShell
      title="Centru de alerte"
      subtitle="Toate evenimentele flotei · DTC, harsh accel/brake, anomalii senzori"
    >
      {/* Stats */}
      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-5">
        <StatCard
          label="TOTAL"
          value={stats.total}
          color="cyan"
          icon={<AlertOctagon size={18} />}
        />
        <StatCard
          label="CRITICE"
          value={stats.critical}
          color="danger"
          icon={<AlertOctagon size={18} />}
        />
        <StatCard
          label="WARNING"
          value={stats.warning}
          color="warn"
          icon={<AlertTriangle size={18} />}
        />
        <StatCard
          label="INFO"
          value={stats.info}
          color="cyan"
          icon={<Info size={18} />}
        />
        <StatCard
          label="REZOLVATE"
          value={stats.resolved}
          color="ok"
          icon={<CheckCircle2 size={18} />}
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
            placeholder="cauta cod, titlu, vehicul, sofer..."
            className="w-full rounded-lg border border-border/70 bg-surface/60 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none"
          />
        </div>
        <div className="flex items-center gap-1 rounded-lg border border-border/70 bg-surface/60 p-1">
          {(['all', 'critical', 'warning', 'info'] as SeverityFilter[]).map(
            (s) => (
              <button
                key={s}
                onClick={() => setSeverity(s)}
                className={`rounded-md px-3 py-1.5 font-display text-[10px] font-bold tracking-widest transition ${
                  severity === s
                    ? s === 'critical'
                      ? 'bg-danger/15 text-danger'
                      : s === 'warning'
                        ? 'bg-warn/15 text-warn'
                        : s === 'info'
                          ? 'bg-cyan/15 text-cyan'
                          : 'bg-cyan/15 text-cyan'
                    : 'text-textMuted hover:text-white'
                }`}
              >
                {s === 'all' ? 'TOATE' : s.toUpperCase()}
              </button>
            ),
          )}
        </div>
        <div className="flex items-center gap-1 rounded-lg border border-border/70 bg-surface/60 p-1">
          {(['unresolved', 'resolved', 'all'] as StateFilter[]).map((s) => (
            <button
              key={s}
              onClick={() => setState(s)}
              className={`rounded-md px-3 py-1.5 font-display text-[10px] font-bold tracking-widest transition ${
                state === s ? 'bg-cyan/15 text-cyan' : 'text-textMuted hover:text-white'
              }`}
            >
              {s === 'unresolved'
                ? 'ACTIVE'
                : s === 'resolved'
                  ? 'INCHISE'
                  : 'TOATE'}
            </button>
          ))}
        </div>
      </div>

      {/* Alert list */}
      <div className="space-y-2">
        {loading ? (
          <div className="rounded-2xl border border-border/60 bg-surface/40 p-12 text-center text-textDim">
            Se incarca alertele...
          </div>
        ) : filtered.length === 0 ? (
          <div className="rounded-2xl border border-border/60 bg-surface/40 p-12 text-center text-textDim">
            Nicio alerta pentru filtrul curent.
          </div>
        ) : (
          filtered.map((e) => {
            const sevStyle =
              e.severity === 'critical'
                ? 'border-danger/40 bg-danger/5'
                : e.severity === 'warning'
                  ? 'border-warn/40 bg-warn/5'
                  : 'border-cyan/40 bg-cyan/5'
            const sevText =
              e.severity === 'critical'
                ? 'text-danger'
                : e.severity === 'warning'
                  ? 'text-warn'
                  : 'text-cyan'
            const SevIcon =
              e.severity === 'critical'
                ? AlertOctagon
                : e.severity === 'warning'
                  ? AlertTriangle
                  : Info
            return (
              <div
                key={e.id}
                className={`flex items-start gap-4 rounded-xl border p-4 transition hover:shadow-[0_0_24px_-12px_currentColor] ${sevStyle}`}
              >
                <SevIcon size={20} className={sevText} />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span
                      className={`font-display text-sm font-black tracking-wider ${sevText}`}
                    >
                      {e.code ?? e.type.toUpperCase()}
                    </span>
                    <span className="rounded bg-bg/60 px-2 py-0.5 font-display text-[10px] font-bold tracking-widest text-textMuted">
                      {e.severity.toUpperCase()}
                    </span>
                    {e.resolved_at && (
                      <span className="rounded bg-ok/15 px-2 py-0.5 font-display text-[10px] font-bold tracking-widest text-ok">
                        REZOLVAT
                      </span>
                    )}
                    <span className="ml-auto font-mono text-[10px] text-textMuted">
                      {new Date(e.ts).toLocaleString('ro-RO')}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-white">{e.title}</p>
                  {e.description && (
                    <p className="mt-1 text-[11px] text-textMuted">
                      {e.description}
                    </p>
                  )}
                  <div className="mt-2 flex flex-wrap items-center gap-3 text-[11px]">
                    {e.plate && (
                      <Link
                        href={`/vehicles/${e.vehicle_id}`}
                        className="text-cyan hover:underline"
                      >
                        {e.plate}
                      </Link>
                    )}
                    {e.driver_name && (
                      <span className="text-textMuted">
                        Sofer: <span className="text-white">{e.driver_name}</span>
                      </span>
                    )}
                  </div>
                  {e.code && /^[PBCU]\d{4}$/i.test(e.code) && (
                    <AIDtcExplainer
                      code={e.code}
                      plate={e.plate}
                      make={e.make}
                      model={e.model}
                      title={e.title}
                      description={e.description ?? undefined}
                    />
                  )}
                </div>
                {!e.resolved_at && (
                  <button
                    onClick={() => markResolved(e.id)}
                    className="shrink-0 rounded-lg border border-ok/40 bg-ok/10 px-3 py-1.5 font-display text-[10px] font-bold tracking-widest text-ok transition hover:bg-ok/20"
                  >
                    <CheckCircle2 size={12} className="mr-1 inline" />
                    REZOLVA
                  </button>
                )}
              </div>
            )
          })
        )}
      </div>
    </PageShell>
  )
}
