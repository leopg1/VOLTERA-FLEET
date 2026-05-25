'use client'

import { useEffect, useState } from 'react'
import { createBrowserClient } from '@supabase/ssr'
import {
  applyRealTelemetry,
  ingestRealEvent,
  REAL_DEVICE_VEHICLE_ID,
} from '@/lib/mock/simulator'
import type { FleetEvent } from '@/lib/supabase'
import { Wifi, WifiOff } from 'lucide-react'

/**
 * RealDeviceBridge — subscribe la Supabase REAL pentru a primi telemetria
 * device-ului tau OBD-II conectat (tableta cu Flutter app).
 *
 * Cand telemetria reala soseste, suprascrie data simulata pentru vehiculul
 * cu UUID = REAL_DEVICE_VEHICLE_ID.
 *
 * Configureaza in Flutter app (MORE → FLEET CLOUD):
 *   - Supabase URL: cel din .env.local
 *   - Anon Key: cel din .env.local
 *   - Vehicle ID: 00000000-0000-0000-0000-000000000099
 *
 * Daca Supabase nu e reachable, componenta esueaza silent — mock simulatorul
 * continua sa avanseze vehiculul cu date sintetice.
 */
export default function RealDeviceBridge() {
  const [status, setStatus] = useState<
    'connecting' | 'subscribed' | 'live' | 'offline'
  >('connecting')
  const [lastSeenMs, setLastSeenMs] = useState<number | null>(null)

  useEffect(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
    if (!url || !key) {
      setStatus('offline')
      return
    }

    let client: ReturnType<typeof createBrowserClient> | null = null
    let channel: ReturnType<NonNullable<typeof client>['channel']> | null = null
    try {
      client = createBrowserClient(url, key, {
        realtime: { params: { eventsPerSecond: 5 } },
      })
    } catch {
      setStatus('offline')
      return
    }

    type Sample = {
      lat?: number | null
      lon?: number | null
      speed_kmh?: number | null
      rpm?: number | null
      coolant?: number | null
      throttle?: number | null
      engine_load?: number | null
      battery?: number | null
      fuel_pct?: number | null
      maf?: number | null
      ts?: string
    }

    let lastTsApplied = ''
    const applyIfNew = (s: Sample) => {
      if (!s.ts || s.ts === lastTsApplied) return false
      lastTsApplied = s.ts
      applyRealTelemetry(REAL_DEVICE_VEHICLE_ID, s)
      setStatus('live')
      setLastSeenMs(Date.now())
      return true
    }

    // ---- Realtime subscription (WebSocket) ----
    channel = client
      .channel('real-device-bridge')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'telemetry_samples',
          filter: `vehicle_id=eq.${REAL_DEVICE_VEHICLE_ID}`,
        },
        (payload: { new: Record<string, unknown> }) => {
          applyIfNew(payload.new as Sample)
        },
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'events',
          filter: `vehicle_id=eq.${REAL_DEVICE_VEHICLE_ID}`,
        },
        (payload: { new: Record<string, unknown> }) => {
          ingestRealEvent(payload.new as unknown as FleetEvent)
        },
      )
      .subscribe((sub: string) => {
        if (sub === 'SUBSCRIBED') {
          setStatus((prev) => (prev === 'connecting' ? 'subscribed' : prev))
        }
      })

    // ---- Polling fallback (REST) — fetch ultimul sample la 3s ----
    // Daca realtime WebSocket are probleme, polling-ul garanteaza ca primim date
    const pollLatest = async () => {
      try {
        const { data } = await client
          .from('telemetry_samples')
          .select('ts,lat,lon,speed_kmh,rpm,coolant,throttle,engine_load,battery,fuel_pct,maf')
          .eq('vehicle_id', REAL_DEVICE_VEHICLE_ID)
          .order('ts', { ascending: false })
          .limit(1)
        if (data && data.length > 0) {
          applyIfNew(data[0] as Sample)
        }
      } catch {
        /* ignora — supabase poate fi indisponibil */
      }
    }
    pollLatest() // primul fetch imediat
    const pollInterval = window.setInterval(pollLatest, 3000)

    // ---- Polling fallback pentru events — fetch ultimele 10 events la 4s ----
    // Dedupe-ul se face in ingestRealEvent (seenRealEventIds set).
    const pollEvents = async () => {
      try {
        const { data } = await client
          .from('events')
          .select('*')
          .eq('vehicle_id', REAL_DEVICE_VEHICLE_ID)
          .order('ts', { ascending: false })
          .limit(10)
        if (data && data.length > 0) {
          // Inversam ca cele mai vechi sa fie ingerate prima — ordine cronologica
          for (const ev of [...data].reverse()) {
            ingestRealEvent(ev as unknown as FleetEvent)
          }
        }
      } catch {
        /* ignora */
      }
    }
    pollEvents()
    const pollEventsInterval = window.setInterval(pollEvents, 4000)

    // ---- Watchdog: marcheaza offline daca nu mai vine nimic > 15s ----
    const offlineCheck = window.setInterval(() => {
      setLastSeenMs((current) => {
        if (current && Date.now() - current > 15_000) {
          setStatus((prev) => (prev === 'live' ? 'subscribed' : prev))
        }
        return current
      })
    }, 2000)

    return () => {
      clearInterval(offlineCheck)
      clearInterval(pollInterval)
      clearInterval(pollEventsInterval)
      if (channel && client) {
        client.removeChannel(channel)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className="pointer-events-none fixed bottom-[88px] left-4 z-40 flex items-center gap-1.5 rounded-full border border-border/60 bg-bg/85 px-2.5 py-1 font-mono text-[10px] tracking-widest backdrop-blur-md">
      {status === 'live' ? (
        <>
          <Wifi size={11} className="text-ok" />
          <span className="text-ok">DEVICE LIVE</span>
          {lastSeenMs && (
            <span className="text-textDim">
              · {Math.max(0, Math.round((Date.now() - lastSeenMs) / 1000))}s
            </span>
          )}
        </>
      ) : status === 'subscribed' ? (
        <>
          <span className="h-2 w-2 animate-pulse rounded-full bg-cyan" />
          <span className="text-cyan">DEVICE: gata · astept date</span>
        </>
      ) : status === 'connecting' ? (
        <>
          <span className="h-2 w-2 animate-pulse rounded-full bg-warn" />
          <span className="text-textMuted">DEVICE: conectare...</span>
        </>
      ) : (
        <>
          <WifiOff size={11} className="text-textMuted" />
          <span className="text-textMuted">DEVICE: offline / DNS blocat</span>
        </>
      )}
    </div>
  )
}
