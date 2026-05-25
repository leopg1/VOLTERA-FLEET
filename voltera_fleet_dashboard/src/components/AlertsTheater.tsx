'use client'

import { useEffect, useRef, useState } from 'react'
import { supabase, type FleetEvent } from '@/lib/supabase'
import { AlertOctagon, X, Volume2, VolumeX } from 'lucide-react'

/**
 * AlertsTheater — "spectacolul" cinematic care apare la alerte CRITICE.
 *
 * Cand soseste un eveniment cu severity='critical' prin realtime, declanseaza:
 *   1. Banner rosu pulsatoriu de sus, slide-in 350ms
 *   2. Audio ping sintetic (Web Audio API, ~440ms)
 *   3. Voice synthesis (Web Speech API) anunta in romana
 *   4. Bar de progres drain pe 4s
 *   5. Slide-out + cleanup
 *
 * Globally mounted din (app)/layout.tsx → functioneaza pe orice ecran.
 */

const DISPLAY_MS = 4200
const EXIT_FADE_MS = 350

const STORAGE_KEY = 'voltera:alerts-theater-muted'

export default function AlertsTheater() {
  const [activeAlert, setActiveAlert] = useState<FleetEvent | null>(null)
  const [exiting, setExiting] = useState(false)
  const [muted, setMuted] = useState(false)
  const audioCtxRef = useRef<AudioContext | null>(null)
  const timersRef = useRef<number[]>([])

  // Hidrateaza preferinta mute
  useEffect(() => {
    try {
      if (localStorage.getItem(STORAGE_KEY) === 'true') setMuted(true)
    } catch {
      /* localStorage indisponibil */
    }
  }, [])

  const toggleMute = () => {
    const next = !muted
    setMuted(next)
    try {
      localStorage.setItem(STORAGE_KEY, String(next))
    } catch {
      /* ignora */
    }
  }

  // Subscribe la evenimente
  useEffect(() => {
    const channel = supabase
      .channel('alerts-theater')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'events' },
        (payload) => {
          const event = payload.new as FleetEvent
          if (event.severity === 'critical') {
            triggerTheater(event)
          }
        },
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
      timersRef.current.forEach((t) => clearTimeout(t))
      timersRef.current = []
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [muted])

  const triggerTheater = (event: FleetEvent) => {
    // Anuleaza timer-ele in zbor
    timersRef.current.forEach((t) => clearTimeout(t))
    timersRef.current = []

    setActiveAlert(event)
    setExiting(false)

    if (!muted) {
      playPing()
      // Mic delay ca ping-ul + vocea sa nu se calce
      window.setTimeout(() => speakAlert(event), 280)
    }

    // Schedule exit animation
    const exitTimer = window.setTimeout(() => {
      setExiting(true)
    }, DISPLAY_MS - EXIT_FADE_MS)

    const cleanupTimer = window.setTimeout(() => {
      setActiveAlert(null)
      setExiting(false)
    }, DISPLAY_MS)

    timersRef.current.push(exitTimer, cleanupTimer)
  }

  const dismissNow = () => {
    timersRef.current.forEach((t) => clearTimeout(t))
    timersRef.current = []
    setExiting(true)
    const t = window.setTimeout(() => {
      setActiveAlert(null)
      setExiting(false)
    }, EXIT_FADE_MS)
    timersRef.current.push(t)
  }

  const playPing = () => {
    try {
      const Ctx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext })
          .webkitAudioContext
      if (!audioCtxRef.current) audioCtxRef.current = new Ctx()
      const ctx = audioCtxRef.current
      // Doua note scurte, sweep, descrescator — sound "alert urgent dar curat"
      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'sine'
      osc1.frequency.setValueAtTime(880, ctx.currentTime)
      osc1.frequency.exponentialRampToValueAtTime(1320, ctx.currentTime + 0.12)
      gain1.gain.setValueAtTime(0.25, ctx.currentTime)
      gain1.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.18)
      osc1.connect(gain1).connect(ctx.destination)
      osc1.start()
      osc1.stop(ctx.currentTime + 0.2)

      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'sine'
      osc2.frequency.setValueAtTime(660, ctx.currentTime + 0.18)
      osc2.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.3)
      gain2.gain.setValueAtTime(0.2, ctx.currentTime + 0.18)
      gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4)
      osc2.connect(gain2).connect(ctx.destination)
      osc2.start(ctx.currentTime + 0.18)
      osc2.stop(ctx.currentTime + 0.42)
    } catch {
      /* AudioContext indisponibil sau blocked */
    }
  }

  const speakAlert = (event: FleetEvent) => {
    try {
      if (!('speechSynthesis' in window)) return
      const u = new SpeechSynthesisUtterance(
        `Alertă critică. ${event.title}.`,
      )
      // Alege o voce in romana daca exista, altfel default
      const voices = window.speechSynthesis.getVoices()
      const ro = voices.find((v) => v.lang.startsWith('ro'))
      if (ro) u.voice = ro
      u.lang = 'ro-RO'
      u.rate = 1.05
      u.pitch = 1.0
      u.volume = 0.9
      window.speechSynthesis.cancel() // anuleaza orice e in coada
      window.speechSynthesis.speak(u)
    } catch {
      /* speech sintetic indisponibil */
    }
  }

  return (
    <>
      {/* Buton mute global — vizibil mereu, mic, sus-dreapta intre topbar si margine */}
      <button
        type="button"
        onClick={toggleMute}
        aria-label={muted ? 'Activeaza alerte sonore' : 'Mute alerte sonore'}
        title={muted ? 'Alerte sonore: OFF' : 'Alerte sonore: ON'}
        className="pointer-events-auto fixed right-4 top-[60px] z-40 flex h-7 w-7 items-center justify-center rounded-full border border-border/60 bg-surface/80 text-textMuted backdrop-blur-md transition hover:border-cyan/60 hover:text-cyan"
      >
        {muted ? <VolumeX size={13} /> : <Volume2 size={13} />}
      </button>

      {/* Banner cinematic */}
      {activeAlert && (
        <div
          role="alert"
          aria-live="assertive"
          className={`pointer-events-auto fixed left-0 right-0 top-0 z-[60] ${
            exiting ? 'alerts-theater-exit' : 'alerts-theater-enter'
          }`}
        >
          <div className="relative overflow-hidden bg-gradient-to-r from-red-700 via-red-600 to-red-700 shadow-[0_8px_32px_-8px_rgba(220,38,38,0.6)]">
            <div className="flex items-center gap-4 px-6 py-3.5">
              <div className="relative shrink-0">
                <AlertOctagon
                  size={32}
                  className="text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]"
                />
                <span className="absolute -right-1 -top-1 h-3 w-3">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-white opacity-80" />
                  <span className="relative inline-flex h-3 w-3 rounded-full bg-white" />
                </span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-display text-[10px] font-black uppercase tracking-[0.2em] text-white/85">
                  Alertă critică ·{' '}
                  {new Date(activeAlert.ts).toLocaleTimeString('ro-RO')}
                  {activeAlert.code ? ` · ${activeAlert.code}` : ''}
                </p>
                <p className="truncate font-display text-lg font-bold leading-tight text-white">
                  {activeAlert.title}
                </p>
                {activeAlert.description && (
                  <p className="mt-0.5 truncate text-xs text-white/90">
                    {activeAlert.description}
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={dismissNow}
                aria-label="Inchide alerta"
                className="shrink-0 rounded-full bg-white/15 p-2 text-white transition hover:bg-white/30"
              >
                <X size={16} />
              </button>
            </div>
            {/* Progress drain bar */}
            <div className="absolute bottom-0 left-0 h-0.5 w-full bg-white/15">
              <div className="alerts-theater-progress h-full origin-left bg-white" />
            </div>
          </div>
        </div>
      )}
    </>
  )
}
