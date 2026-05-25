'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useEffect, useState } from 'react'
import {
  LayoutDashboard,
  Car,
  Users,
  Route,
  AlertTriangle,
  BarChart3,
  Settings,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'

const NAV = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard, exact: true },
  { href: '/vehicles', label: 'Vehicule', icon: Car },
  { href: '/drivers', label: 'Soferi', icon: Users },
  { href: '/trips', label: 'Trasee', icon: Route },
  { href: '/alerts', label: 'Alerte', icon: AlertTriangle },
  { href: '/analytics', label: 'Analytics', icon: BarChart3 },
  { href: '/settings', label: 'Setari', icon: Settings },
]

const STORAGE_KEY = 'voltera:sidebar-collapsed'

export default function Sidebar() {
  const pathname = usePathname()
  const [collapsed, setCollapsed] = useState(false)
  const [mounted, setMounted] = useState(false)

  // Hydrate preference din localStorage (evita flash de hidratare)
  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored === 'true') setCollapsed(true)
    } catch {
      /* localStorage indisponibil — ignora */
    }
    setMounted(true)
  }, [])

  const toggle = () => {
    const next = !collapsed
    setCollapsed(next)
    try {
      localStorage.setItem(STORAGE_KEY, String(next))
    } catch {
      /* ignora */
    }
  }

  return (
    <aside
      data-collapsed={collapsed}
      className={`relative flex h-full shrink-0 flex-col border-r border-border/60 bg-surface/60 backdrop-blur-xl transition-[width] duration-300 ease-out ${
        collapsed ? 'w-[64px]' : 'w-[232px]'
      }`}
      style={{ transitionTimingFunction: 'cubic-bezier(0.25, 1, 0.5, 1)' }}
    >
      {/* Brand */}
      <div
        className={`flex items-center border-b border-border/60 ${
          collapsed ? 'justify-center px-3 py-5' : 'gap-3 px-5 py-5'
        }`}
      >
        <VolteraLogo />
        {!collapsed && (
          <div className="min-w-0 leading-tight">
            <h1 className="truncate font-display text-sm font-black tracking-[0.18em] text-white">
              VOLTERA
            </h1>
            <p className="truncate text-[9px] font-medium tracking-widest text-cyan">
              FLEET CONTROL
            </p>
          </div>
        )}
      </div>

      {/* Section label */}
      {!collapsed && (
        <div className="px-5 pb-2 pt-5 font-display text-[9px] font-bold tracking-widest text-textDim">
          NAVIGARE
        </div>
      )}

      {/* Nav */}
      <nav className={`flex-1 space-y-0.5 ${collapsed ? 'px-2 pt-5' : 'px-3'}`}>
        {NAV.map((item) => {
          const Icon = item.icon
          const active = item.exact
            ? pathname === item.href
            : pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              title={collapsed ? item.label : undefined}
              aria-label={item.label}
              className={`group relative flex items-center rounded-lg transition ${
                collapsed
                  ? 'justify-center px-2 py-2.5'
                  : 'gap-3 px-3 py-2.5'
              } ${
                active
                  ? 'bg-cyan/10 text-white'
                  : 'text-textMuted hover:bg-surface/60 hover:text-white'
              }`}
            >
              {active && (
                <span
                  className={`absolute top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-full bg-cyan shadow-[0_0_8px] shadow-cyan ${
                    collapsed ? '-left-2' : 'left-0'
                  }`}
                />
              )}
              <Icon
                size={collapsed ? 18 : 16}
                className={`shrink-0 ${active ? 'text-cyan' : 'text-textDim'}`}
              />
              {!collapsed && (
                <span
                  className={`truncate font-display text-sm tracking-wider ${
                    active ? 'font-bold' : 'font-medium'
                  }`}
                >
                  {item.label}
                </span>
              )}
            </Link>
          )
        })}
      </nav>

      {/* Footer */}
      <div
        className={`border-t border-border/60 ${
          collapsed ? 'px-3 py-4' : 'px-5 py-4'
        }`}
      >
        <div
          className={`flex items-center text-[10px] font-medium tracking-widest text-textDim ${
            collapsed ? 'justify-center' : 'gap-2'
          }`}
          title={collapsed ? 'SYSTEM ONLINE' : undefined}
        >
          <span className="h-1.5 w-1.5 rounded-full bg-ok shadow-[0_0_6px] shadow-ok" />
          {!collapsed && <span>SYSTEM ONLINE</span>}
        </div>
        {!collapsed && (
          <p className="mt-1 text-[10px] text-textDim">v1.0 · ICE USV · 2026</p>
        )}
      </div>

      {/* Collapse toggle — pe marginea dreapta, vizibil mereu */}
      <button
        type="button"
        onClick={toggle}
        aria-label={collapsed ? 'Extinde meniul' : 'Restrange meniul'}
        title={collapsed ? 'Extinde meniul' : 'Restrange meniul'}
        className="absolute top-7 -right-3 z-20 flex h-6 w-6 items-center justify-center rounded-full border border-border/80 bg-surface text-textMuted shadow-[0_4px_12px_-4px_rgba(0,0,0,0.6)] transition hover:border-cyan/60 hover:text-cyan focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
      >
        {collapsed ? (
          <ChevronRight size={14} strokeWidth={2.5} />
        ) : (
          <ChevronLeft size={14} strokeWidth={2.5} />
        )}
      </button>
    </aside>
  )
}

function VolteraLogo() {
  return (
    <div className="relative h-9 w-9 shrink-0 rounded-lg bg-bg/80 ring-1 ring-cyan/40 shadow-[0_0_18px_-4px_rgba(0,212,255,0.7)]">
      <svg
        viewBox="0 0 40 40"
        className="absolute inset-0 h-full w-full p-1.5"
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
