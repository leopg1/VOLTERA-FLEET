'use client'

import { useEffect, useState } from 'react'
import { supabase, FleetEvent } from '@/lib/supabase'
import { AlertOctagon, AlertTriangle, Info } from 'lucide-react'

export default function AlertsTicker({
  onSelectVehicle,
}: {
  onSelectVehicle: (id: string) => void
}) {
  const [alerts, setAlerts] = useState<FleetEvent[]>([])

  useEffect(() => {
    let cancelled = false

    supabase
      .from('events')
      .select('*')
      .is('resolved_at', null)
      .order('ts', { ascending: false })
      .limit(8)
      .then(({ data }) => {
        if (!cancelled && data) setAlerts(data as FleetEvent[])
      })

    const channel = supabase
      .channel('global-events')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'events' },
        (payload) => {
          setAlerts((prev) => [payload.new as FleetEvent, ...prev].slice(0, 8))
        },
      )
      .subscribe()

    return () => {
      cancelled = true
      supabase.removeChannel(channel)
    }
  }, [])

  const ico = (s: FleetEvent['severity']) =>
    s === 'critical' ? (
      <AlertOctagon size={14} className="text-danger" />
    ) : s === 'warning' ? (
      <AlertTriangle size={14} className="text-warn" />
    ) : (
      <Info size={14} className="text-cyan" />
    )

  return (
    <div className="pointer-events-auto fixed right-3 top-[64px] z-20 w-[340px] max-h-[60vh] overflow-y-auto rounded-2xl border border-border/70 bg-surface/90 shadow-2xl backdrop-blur-xl">
      <div className="sticky top-0 z-10 flex items-center justify-between border-b border-border/60 bg-surface/95 px-3 py-2.5 backdrop-blur">
        <span className="flex items-center gap-1.5 font-display text-[10px] font-black tracking-widest text-textMuted">
          <AlertOctagon size={12} className="text-danger" /> ALERTS INBOX
        </span>
        <span className="rounded-full bg-danger/15 px-2 py-0.5 font-mono text-[10px] font-bold text-danger">
          {alerts.length}
        </span>
      </div>
      {alerts.length === 0 ? (
        <p className="px-3 py-4 text-center text-xs text-textDim">
          Toate sistemele OK.
        </p>
      ) : (
        <ul className="space-y-1 p-2">
          {alerts.map((a) => (
            <li
              key={a.id}
              onClick={() => onSelectVehicle(a.vehicle_id)}
              className="cursor-pointer rounded-lg border border-border/50 bg-surface/40 p-2.5 transition hover:border-cyan/60 hover:bg-surface/70"
            >
              <div className="flex items-center gap-2">
                {ico(a.severity)}
                <span className="font-display text-xs font-black tracking-wider text-white">
                  {a.code ?? a.type.toUpperCase()}
                </span>
                <span className="ml-auto font-mono text-[10px] text-textDim">
                  {new Date(a.ts).toLocaleTimeString('ro-RO')}
                </span>
              </div>
              <p className="mt-0.5 line-clamp-2 text-[11px] text-textMuted">
                {a.title}
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
