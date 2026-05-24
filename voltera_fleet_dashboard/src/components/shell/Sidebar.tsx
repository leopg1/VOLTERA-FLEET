'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard,
  Car,
  Users,
  Route,
  AlertTriangle,
  BarChart3,
  Settings,
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

export default function Sidebar() {
  const pathname = usePathname()

  return (
    <aside className="flex h-full w-[232px] shrink-0 flex-col border-r border-border/60 bg-surface/60 backdrop-blur-xl">
      {/* Brand */}
      <div className="flex items-center gap-3 border-b border-border/60 px-5 py-5">
        <VolteraLogo />
        <div className="leading-tight">
          <h1 className="font-display text-sm font-black tracking-[0.18em] text-white">
            VOLTERA
          </h1>
          <p className="text-[9px] font-medium tracking-widest text-cyan">
            FLEET CONTROL
          </p>
        </div>
      </div>

      {/* Section label */}
      <div className="px-5 pb-2 pt-5 font-display text-[9px] font-bold tracking-widest text-textDim">
        NAVIGARE
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-0.5 px-3">
        {NAV.map((item) => {
          const Icon = item.icon
          const active = item.exact
            ? pathname === item.href
            : pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`group relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition ${
                active
                  ? 'bg-cyan/10 text-white'
                  : 'text-textMuted hover:bg-surface/60 hover:text-white'
              }`}
            >
              {active && (
                <span className="absolute left-0 top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-full bg-cyan shadow-[0_0_8px] shadow-cyan" />
              )}
              <Icon
                size={16}
                className={active ? 'text-cyan' : 'text-textDim'}
              />
              <span
                className={`font-display tracking-wider ${
                  active ? 'font-bold' : 'font-medium'
                }`}
              >
                {item.label}
              </span>
            </Link>
          )
        })}
      </nav>

      {/* Footer */}
      <div className="border-t border-border/60 px-5 py-4">
        <div className="flex items-center gap-2 text-[10px] font-medium tracking-widest text-textDim">
          <span className="h-1.5 w-1.5 rounded-full bg-ok shadow-[0_0_6px] shadow-ok" />
          SYSTEM ONLINE
        </div>
        <p className="mt-1 text-[10px] text-textDim">v1.0 · ICE USV · 2026</p>
      </div>
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
