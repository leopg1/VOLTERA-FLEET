'use client'

/**
 * Demo Control Panel
 *
 * Widget plutitor bottom-right, vizibil DOAR cand NEXT_PUBLIC_DEMO_MODE=true.
 * Da control direct asupra simulatorului local:
 *  - Pauza / Play
 *  - Multiplicator viteza simulare (1x / 2x / 5x)
 *  - Butoane trigger pentru evenimente critice (DTC, low battery, misfire)
 *
 * Acesta NU e UI pentru produs final — e un instrument de prezentare.
 * Ascuns automat in productie.
 */

import { useEffect, useState } from 'react'
import {
  Pause,
  Play,
  Zap,
  AlertOctagon,
  BatteryWarning,
  Activity,
  ChevronDown,
  Wrench,
  Orbit,
} from 'lucide-react'
import {
  setPaused,
  getPaused,
  setSpeedMultiplier,
  getSpeedMultiplier,
  triggerDtc,
  triggerLowBattery,
  resolveAlerts,
  getVehiclesList,
  type VehicleState,
} from '@/lib/mock/simulator'
import { constellationFlag } from '@/lib/ui-state'

const DEMO_MODE = process.env.NEXT_PUBLIC_DEMO_MODE === 'true'

export default function DemoControlPanel() {
  const [open, setOpen] = useState(false)
  const [paused, setPausedState] = useState(false)
  const [speed, setSpeed] = useState<1 | 2 | 5>(1)
  const [vehicles, setVehicles] = useState<VehicleState[]>([])
  const [constellation, setConstellation] = useState(false)

  useEffect(() => {
    if (!DEMO_MODE) return
    // Hidrateaza state din simulator (poate fi pornit deja)
    setPausedState(getPaused())
    setSpeed(getSpeedMultiplier() as 1 | 2 | 5)
    setVehicles(getVehiclesList())
    setConstellation(constellationFlag.get())
    // Refresh list periodic (in caz ca se schimba dinamic)
    const id = setInterval(() => setVehicles(getVehiclesList()), 5000)
    const unsub = constellationFlag.subscribe(setConstellation)
    return () => {
      clearInterval(id)
      unsub()
    }
  }, [])

  if (!DEMO_MODE) return null

  const togglePause = () => {
    const next = !paused
    setPaused(next)
    setPausedState(next)
  }

  const cycleSpeed = () => {
    const seq: Array<1 | 2 | 5> = [1, 2, 5]
    const next = seq[(seq.indexOf(speed) + 1) % seq.length]
    setSpeedMultiplier(next)
    setSpeed(next)
  }

  const pick = (idx: number) => vehicles[idx % Math.max(1, vehicles.length)]

  const fireDtc = () => {
    const v = pick(0)
    if (!v) return
    triggerDtc(
      v.id,
      'P0420',
      `DTC P0420 — ${v.plate}`,
      'Eficienta catalizatorului sub prag. Bancul 1 raporteaza valori O2 inadecvate.',
    )
  }

  const fireMisfire = () => {
    const v = pick(1)
    if (!v) return
    triggerDtc(
      v.id,
      'P0301',
      `DTC P0301 — ${v.plate}`,
      'Misfire detectat pe cilindrul 1. Verifica bujie / bobina / injector.',
    )
  }

  const fireBattery = () => {
    const v = pick(2)
    if (!v) return
    triggerLowBattery(v.id)
  }

  const clearAlerts = () => {
    vehicles.forEach((v) => resolveAlerts(v.id))
  }

  return (
    <aside
      className={`pointer-events-auto fixed bottom-4 left-4 z-40 select-none rounded-2xl border border-cyan/30 bg-bg/95 shadow-[0_12px_40px_-12px_rgba(0,212,255,0.45)] backdrop-blur-xl transition-all duration-300 ${
        open ? 'w-[300px]' : 'w-auto'
      }`}
      style={{ transitionTimingFunction: 'cubic-bezier(0.25, 1, 0.5, 1)' }}
    >
      {/* Header */}
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center gap-2 px-3 py-2.5"
        aria-label={open ? 'Restrange panou demo' : 'Deschide panou demo'}
      >
        <span className="relative flex h-2 w-2 shrink-0">
          <span
            className={`absolute inline-flex h-full w-full rounded-full ${
              paused ? 'bg-warn' : 'bg-cyan'
            } opacity-75 ${paused ? '' : 'animate-ping'}`}
          />
          <span
            className={`relative inline-flex h-2 w-2 rounded-full ${
              paused ? 'bg-warn' : 'bg-cyan'
            }`}
          />
        </span>
        <span className="font-display text-[10px] font-black tracking-[0.2em] text-cyan">
          DEMO
        </span>
        {open && (
          <span className="ml-auto font-mono text-[10px] text-textMuted">
            {vehicles.length} vehicule · {speed}x
            {paused && ' · PAUZA'}
          </span>
        )}
        <ChevronDown
          size={12}
          className={`shrink-0 text-textMuted transition-transform ${
            open ? 'rotate-180' : 'rotate-0'
          }`}
        />
      </button>

      {open && (
        <div className="border-t border-border/60 p-3">
          {/* Transport controls */}
          <div className="mb-3 flex items-center gap-2">
            <button
              type="button"
              onClick={togglePause}
              className="flex flex-1 items-center justify-center gap-1.5 rounded-lg border border-border/70 bg-surface/60 px-3 py-2 text-xs font-medium text-white transition hover:border-cyan/60 hover:bg-surface"
              aria-label={paused ? 'Reia' : 'Pauza'}
            >
              {paused ? <Play size={13} /> : <Pause size={13} />}
              <span className="font-display tracking-wider">
                {paused ? 'PLAY' : 'PAUSE'}
              </span>
            </button>
            <button
              type="button"
              onClick={cycleSpeed}
              className="flex items-center justify-center gap-1.5 rounded-lg border border-border/70 bg-surface/60 px-3 py-2 text-xs font-medium text-white transition hover:border-cyan/60 hover:bg-surface"
              aria-label={`Viteza simulare ${speed}x`}
            >
              <Zap size={13} className="text-cyan" />
              <span className="font-display tracking-wider tabular-nums">
                {speed}x
              </span>
            </button>
          </div>

          {/* Constellation toggle */}
          <button
            type="button"
            onClick={() => constellationFlag.set(!constellation)}
            className={`mb-3 flex w-full items-center justify-between rounded-lg border px-3 py-2 text-xs transition ${
              constellation
                ? 'border-cyan/70 bg-cyan/10 text-cyan'
                : 'border-border/70 bg-surface/40 text-textMuted hover:border-cyan/50 hover:text-white'
            }`}
          >
            <span className="flex items-center gap-2">
              <Orbit
                size={13}
                className={constellation ? 'animate-spin' : ''}
                style={constellation ? { animationDuration: '6s' } : {}}
              />
              <span className="font-display tracking-wider">CONSTELLATION 3D</span>
            </span>
            <span
              className={`rounded px-1.5 py-0.5 font-mono text-[9px] font-bold ${
                constellation ? 'bg-cyan/20 text-cyan' : 'bg-surface text-textDim'
              }`}
            >
              {constellation ? 'ON' : 'OFF'}
            </span>
          </button>

          {/* Section label */}
          <div className="mb-2 font-display text-[9px] font-bold tracking-widest text-textDim">
            TRIGGER EVENIMENTE
          </div>

          <div className="space-y-1.5">
            <TriggerButton
              icon={<AlertOctagon size={13} />}
              label="DTC P0420 (catalizator)"
              hint={vehicles[0]?.plate ?? '—'}
              onClick={fireDtc}
              tone="danger"
            />
            <TriggerButton
              icon={<Activity size={13} />}
              label="Misfire P0301"
              hint={vehicles[1]?.plate ?? '—'}
              onClick={fireMisfire}
              tone="danger"
            />
            <TriggerButton
              icon={<BatteryWarning size={13} />}
              label="Tensiune baterie joasa"
              hint={vehicles[2]?.plate ?? '—'}
              onClick={fireBattery}
              tone="danger"
            />
            <TriggerButton
              icon={<Wrench size={13} />}
              label="Rezolva toate alertele"
              hint="reset status"
              onClick={clearAlerts}
              tone="neutral"
            />
          </div>

          <p className="mt-3 text-[10px] leading-tight text-textDim">
            Date sintetice locale. Nu se trimit la backend. Reseteaza la
            reload-ul paginii.
          </p>
        </div>
      )}
    </aside>
  )
}

function TriggerButton({
  icon,
  label,
  hint,
  onClick,
  tone,
}: {
  icon: React.ReactNode
  label: string
  hint: string
  onClick: () => void
  tone: 'danger' | 'neutral'
}) {
  const toneClass =
    tone === 'danger'
      ? 'border-danger/30 bg-danger/5 text-white hover:border-danger/70 hover:bg-danger/15'
      : 'border-border/70 bg-surface/40 text-white hover:border-cyan/60 hover:bg-surface'
  const iconColor = tone === 'danger' ? 'text-danger' : 'text-cyan'
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-2 rounded-lg border px-3 py-2 text-left text-xs transition ${toneClass}`}
    >
      <span className={`shrink-0 ${iconColor}`}>{icon}</span>
      <span className="flex-1 truncate font-medium">{label}</span>
      <span className="shrink-0 font-mono text-[10px] text-textMuted">
        {hint}
      </span>
    </button>
  )
}
