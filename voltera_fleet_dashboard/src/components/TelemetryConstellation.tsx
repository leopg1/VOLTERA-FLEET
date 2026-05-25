'use client'

import { useEffect, useState } from 'react'
import type maplibregl from 'maplibre-gl'
import type { FleetStatusRow } from '@/lib/supabase'

/**
 * TelemetryConstellation — strat 3D semi-transparent peste harta.
 * Pentru fiecare vehicul, 3 carduri cu telemetrie LIVE orbiteaza in jur:
 *  RPM · Speed · Temp
 * Cardurile rotesc lent (14s ciclu complet), spaced 120°, cu fade in/out
 * pentru iluzie de profunzime (cand cardul e "in spatele" vehiculului).
 *
 * Aer de mission control / Iron Man HUD.
 * Activat via toggle in DemoControlPanel.
 */

type Props = {
  active: boolean
  map: maplibregl.Map | null
  vehicles: FleetStatusRow[]
  livePositions: Record<string, { lat: number; lon: number; ts: number }>
}

export default function TelemetryConstellation({
  active,
  map,
  vehicles,
  livePositions,
}: Props) {
  // Re-project la fiecare frame ca sa urmaresca vehiculul
  const [, setTick] = useState(0)

  useEffect(() => {
    if (!active || !map) return
    let raf = 0
    const loop = () => {
      setTick((t) => (t + 1) % 1_000_000)
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(raf)
  }, [active, map])

  if (!active || !map) return null

  return (
    <div className="pointer-events-none absolute inset-0 z-[15]">
      {vehicles.map((v) => {
        const live = livePositions[v.vehicle_id]
        const lat = live?.lat ?? v.lat
        const lon = live?.lon ?? v.lon
        if (lat == null || lon == null) return null
        const p = map.project([lon, lat])
        return (
          <ConstellationCluster
            key={v.vehicle_id}
            x={p.x}
            y={p.y}
            color={v.color ?? '#00D4FF'}
            rpm={v.rpm}
            speed={v.speed_kmh}
            temp={v.coolant}
          />
        )
      })}
    </div>
  )
}

function ConstellationCluster({
  x,
  y,
  color,
  rpm,
  speed,
  temp,
}: {
  x: number
  y: number
  color: string
  rpm: number | null
  speed: number | null
  temp: number | null
}) {
  // Filtreaza vehicule offscreen pentru perf
  if (x < -100 || y < -100 || x > window.innerWidth + 100 || y > window.innerHeight + 100) {
    return null
  }
  return (
    <div
      className="absolute"
      style={{
        left: `${x}px`,
        top: `${y}px`,
        width: 0,
        height: 0,
      }}
    >
      <OrbitLabel
        delaySec={0}
        color={color}
        value={rpm != null ? rpm.toFixed(0) : '—'}
        unit="RPM"
      />
      <OrbitLabel
        delaySec={-4.66}
        color={color}
        value={speed != null ? speed.toFixed(0) : '—'}
        unit="KM/H"
      />
      <OrbitLabel
        delaySec={-9.33}
        color={color}
        value={temp != null ? temp.toFixed(0) : '—'}
        unit="°C"
      />
    </div>
  )
}

function OrbitLabel({
  delaySec,
  color,
  value,
  unit,
}: {
  delaySec: number
  color: string
  value: string
  unit: string
}) {
  return (
    <div
      className="constellation-orbit"
      style={{
        animationDelay: `${delaySec}s`,
      }}
    >
      <div
        className="constellation-card"
        style={{
          borderColor: `${color}99`,
          boxShadow: `0 4px 18px ${color}55, 0 0 0 1px ${color}40`,
        }}
      >
        <span
          className="constellation-value"
          style={{ color }}
        >
          {value}
        </span>
        <span className="constellation-unit">{unit}</span>
      </div>
    </div>
  )
}
