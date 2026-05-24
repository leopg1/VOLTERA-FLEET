'use client'

import { useState, useTransition } from 'react'
import { signIn } from './actions'
import { Lock, Mail, ShieldAlert } from 'lucide-react'

export default function LoginPage() {
  const [error, setError] = useState<string | null>(null)
  const [pending, startTransition] = useTransition()

  function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setError(null)
    const fd = new FormData(e.currentTarget)
    startTransition(async () => {
      const res = await signIn(fd)
      if (res?.error) setError(res.error)
    })
  }

  return (
    <main className="relative grid min-h-screen w-screen place-items-center overflow-hidden bg-bg text-white">
      {/* Aurora background */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute -top-1/3 left-1/4 h-[60vmax] w-[60vmax] -translate-x-1/2 rounded-full bg-cyan/15 blur-[120px]" />
        <div className="absolute -bottom-1/3 right-1/4 h-[55vmax] w-[55vmax] translate-x-1/2 rounded-full bg-cyan-deep/20 blur-[120px]" />
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_30%,rgba(7,9,15,0.85)_85%)]" />
      </div>

      {/* Card */}
      <div className="relative z-10 w-[min(420px,92vw)] overflow-hidden rounded-2xl border border-border/80 bg-surface/90 shadow-[0_30px_80px_-20px_rgba(0,212,255,0.25)] backdrop-blur-xl">
        <div className="border-b border-border/60 px-7 py-6">
          <div className="flex items-center gap-3">
            <VolteraLogo />
            <div className="leading-tight">
              <h1 className="font-display text-xl font-black tracking-[0.18em] text-white">
                VOLTERA <span className="text-cyan">FLEET</span>
              </h1>
              <p className="text-[10px] font-medium tracking-widest text-textDim">
                ICE USV · DISPATCHER PORTAL
              </p>
            </div>
          </div>
          <p className="mt-5 text-sm text-textMuted">
            Autentificare cu cont dispecer. Daca nu ai inca un cont, intreaba
            adminul flotei sa-ti creeze unul in Supabase.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 px-7 py-6">
          <Field
            id="email"
            label="EMAIL"
            type="email"
            icon={<Mail size={14} />}
            placeholder="dispecer@voltera.usv.ro"
            autoComplete="email"
            required
          />
          <Field
            id="password"
            label="PAROLA"
            type="password"
            icon={<Lock size={14} />}
            placeholder="••••••••••••"
            autoComplete="current-password"
            required
          />

          {error && (
            <div className="flex items-start gap-2 rounded-lg border border-danger/50 bg-danger/10 px-3 py-2.5 text-xs text-danger">
              <ShieldAlert size={14} className="mt-0.5 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <button
            type="submit"
            disabled={pending}
            className="group relative w-full overflow-hidden rounded-lg bg-cyan py-3 font-display text-sm font-black tracking-[0.18em] text-bg transition hover:bg-cyan/90 disabled:opacity-50"
          >
            <span className="relative z-10">
              {pending ? 'SE AUTENTIFICA...' : 'AUTENTIFICARE →'}
            </span>
            <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/30 to-transparent transition-transform duration-700 group-hover:translate-x-full" />
          </button>
        </form>

        <footer className="border-t border-border/60 px-7 py-3 text-[10px] font-medium tracking-widest text-textDim">
          v1.0 · 2026 · Voltera Fleet Telemetry Platform
        </footer>
      </div>
    </main>
  )
}

function Field({
  id,
  label,
  type,
  icon,
  placeholder,
  autoComplete,
  required,
}: {
  id: string
  label: string
  type: string
  icon: React.ReactNode
  placeholder?: string
  autoComplete?: string
  required?: boolean
}) {
  return (
    <div>
      <label
        htmlFor={id}
        className="mb-1.5 flex items-center gap-1.5 font-display text-[10px] font-bold tracking-widest text-textMuted"
      >
        {icon} {label}
      </label>
      <input
        id={id}
        name={id}
        type={type}
        placeholder={placeholder}
        autoComplete={autoComplete}
        required={required}
        className="w-full rounded-lg border border-border/70 bg-bg/60 px-3.5 py-3 text-sm text-white placeholder:text-textDim transition focus:border-cyan/60 focus:bg-bg/80 focus:outline-none focus:ring-2 focus:ring-cyan/15"
      />
    </div>
  )
}

function VolteraLogo() {
  return (
    <div className="relative h-10 w-10 rounded-xl bg-bg/80 ring-1 ring-cyan/40 shadow-[0_0_24px_-4px_rgba(0,212,255,0.7)]">
      <svg
        viewBox="0 0 40 40"
        className="absolute inset-0 h-full w-full p-2"
        fill="none"
      >
        <path
          d="M 6 8 L 16 8 L 20 32 L 24 8 L 34 8 L 26 36 L 14 36 Z"
          fill="#00D4FF"
        />
      </svg>
    </div>
  )
}
