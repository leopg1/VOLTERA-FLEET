'use client'

import { useState, useTransition, useRef, useEffect } from 'react'
import { usePathname } from 'next/navigation'
import { ChevronDown, LogOut, User as UserIcon, Wifi, Sun, Moon } from 'lucide-react'
import { signOut } from '@/app/login/actions'
import { setTheme, getInitialTheme, themeFlag, type Theme } from '@/lib/ui-state'

const PAGE_TITLES: Record<string, string> = {
  '/': 'Dashboard',
  '/vehicles': 'Vehicule',
  '/drivers': 'Soferi',
  '/trips': 'Trasee',
  '/alerts': 'Alerte',
  '/analytics': 'Analytics',
  '/settings': 'Setari',
}

export default function Topbar({
  email,
  displayName,
}: {
  email: string
  displayName: string
}) {
  const pathname = usePathname()
  const [open, setOpen] = useState(false)
  const [pending, startTransition] = useTransition()
  const menuRef = useRef<HTMLDivElement>(null)
  const [theme, setThemeState] = useState<Theme>('dark')

  // Hidratare initiala — citeste din DOM (setat de inline script in layout.tsx)
  useEffect(() => {
    const initial = getInitialTheme()
    setThemeState(initial)
    themeFlag.set(initial)
    const unsub = themeFlag.subscribe(setThemeState)
    return () => {
      unsub()
    }
  }, [])

  const toggleTheme = () => {
    setTheme(theme === 'dark' ? 'light' : 'dark')
  }

  // Inchide menu la click outside
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (!menuRef.current?.contains(e.target as Node)) setOpen(false)
    }
    if (open) document.addEventListener('mousedown', onClick)
    return () => document.removeEventListener('mousedown', onClick)
  }, [open])

  const title =
    PAGE_TITLES[pathname] ??
    (pathname.startsWith('/vehicles/')
      ? 'Detalii vehicul'
      : pathname.startsWith('/trips/')
        ? 'Replay traseu'
        : '')

  const initials = displayName
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()

  return (
    <header className="flex h-14 shrink-0 items-center justify-between border-b border-border/60 bg-bg/70 px-6 backdrop-blur-xl">
      <div>
        <h2 className="font-display text-base font-black tracking-[0.16em] text-white">
          {title.toUpperCase()}
        </h2>
        <p className="text-[10px] font-medium tracking-widest text-textDim">
          {new Date().toLocaleDateString('ro-RO', {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
          })}
        </p>
      </div>

      <div className="flex items-center gap-3">
        {/* Theme toggle */}
        <button
          onClick={toggleTheme}
          title={theme === 'dark' ? 'Comuta pe light mode' : 'Comuta pe dark mode'}
          aria-label="Comuta tema"
          className="relative grid h-8 w-8 place-items-center rounded-full border border-border/70 bg-surface/60 text-textMuted transition hover:border-cyan/60 hover:text-cyan"
        >
          {theme === 'dark' ? <Sun size={14} /> : <Moon size={14} />}
        </button>

        {/* Realtime status */}
        <div className="flex items-center gap-1.5 rounded-full border border-ok/30 bg-ok/5 px-2.5 py-1">
          <span className="relative flex h-1.5 w-1.5">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ok opacity-75" />
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-ok" />
          </span>
          <Wifi size={11} className="text-ok" />
          <span className="font-display text-[10px] font-bold tracking-widest text-ok">
            REALTIME
          </span>
        </div>

        {/* User menu */}
        <div ref={menuRef} className="relative">
          <button
            onClick={() => setOpen((s) => !s)}
            className="flex items-center gap-2.5 rounded-full border border-border/70 bg-surface/60 py-1 pl-1 pr-3 transition hover:border-cyan/40 hover:bg-surface"
          >
            <span className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-cyan to-cyan-deep font-display text-[11px] font-black text-bg">
              {initials || 'V'}
            </span>
            <span className="hidden text-left leading-tight sm:block">
              <span className="block font-display text-xs font-bold text-white">
                {displayName}
              </span>
              <span className="block text-[10px] text-textMuted">
                Dispecer
              </span>
            </span>
            <ChevronDown
              size={14}
              className={`text-textMuted transition ${open ? 'rotate-180' : ''}`}
            />
          </button>

          {open && (
            <div className="absolute right-0 top-[calc(100%+8px)] z-50 w-[260px] overflow-hidden rounded-xl border border-border/70 bg-surface/95 shadow-2xl backdrop-blur-xl">
              <div className="border-b border-border/60 px-4 py-3">
                <p className="font-display text-sm font-bold text-white">
                  {displayName}
                </p>
                <p className="truncate text-[11px] text-textMuted">{email}</p>
              </div>
              <a
                href="/settings"
                className="flex items-center gap-2.5 px-4 py-2.5 text-sm text-textMuted transition hover:bg-surface hover:text-white"
              >
                <UserIcon size={14} /> Profil & setari
              </a>
              <button
                onClick={() =>
                  startTransition(() => {
                    void signOut()
                  })
                }
                disabled={pending}
                className="flex w-full items-center gap-2.5 border-t border-border/60 px-4 py-2.5 text-left text-sm text-danger transition hover:bg-danger/10 disabled:opacity-50"
              >
                <LogOut size={14} /> {pending ? 'Se deconecteaza...' : 'Logout'}
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
