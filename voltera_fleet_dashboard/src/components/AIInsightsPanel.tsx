'use client'

import { useCallback, useEffect, useState } from 'react'
import {
  Sparkles,
  RefreshCw,
  AlertOctagon,
  CheckCircle2,
  Info,
  AlertTriangle,
  Loader2,
  ChevronDown,
  ChevronUp,
} from 'lucide-react'
import type { Insight } from '@/app/api/ai/insights/route'

const ICONS = {
  alert: { Icon: AlertOctagon, color: 'text-danger', ring: 'ring-danger/30' },
  warn: { Icon: AlertTriangle, color: 'text-warn', ring: 'ring-warn/30' },
  ok: { Icon: CheckCircle2, color: 'text-ok', ring: 'ring-ok/30' },
  info: { Icon: Info, color: 'text-cyan', ring: 'ring-cyan/30' },
} as const

export default function AIInsightsPanel() {
  const [insights, setInsights] = useState<Insight[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [generatedAt, setGeneratedAt] = useState<string | null>(null)
  const [collapsed, setCollapsed] = useState(false)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch('/api/ai/insights', { cache: 'no-store' })
      const data = (await res.json()) as {
        insights?: Insight[]
        generatedAt?: string
        error?: string
      }
      if (!res.ok) throw new Error(data.error ?? `HTTP ${res.status}`)
      setInsights(data.insights ?? [])
      setGeneratedAt(data.generatedAt ?? null)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'eroare necunoscuta')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  return (
    <aside className="pointer-events-auto absolute bottom-4 left-4 z-10 w-[300px] overflow-hidden rounded-2xl border border-cyan/30 bg-surface/85 shadow-2xl backdrop-blur-xl">
      <div className="flex items-center gap-2 border-b border-cyan/20 bg-gradient-to-r from-cyan/10 to-transparent px-3 py-2.5">
        <Sparkles size={13} className="text-cyan" />
        <span className="flex-1 font-display text-[10px] font-black tracking-widest text-cyan">
          AI INSIGHTS
        </span>
        <button
          type="button"
          onClick={refresh}
          disabled={loading}
          aria-label="Reincarca insights"
          title="Reincarca"
          className="rounded p-1 text-textMuted transition hover:bg-surface hover:text-cyan disabled:opacity-50"
        >
          {loading ? (
            <Loader2 size={12} className="animate-spin" />
          ) : (
            <RefreshCw size={12} />
          )}
        </button>
        <button
          type="button"
          onClick={() => setCollapsed((c) => !c)}
          aria-label={collapsed ? 'Extinde' : 'Restrange'}
          className="rounded p-1 text-textMuted transition hover:bg-surface hover:text-white"
        >
          {collapsed ? <ChevronDown size={12} /> : <ChevronUp size={12} />}
        </button>
      </div>

      {!collapsed && (
        <div className="max-h-[50vh] space-y-2 overflow-y-auto p-3">
          {loading && insights.length === 0 && (
            <div className="flex items-center gap-2 px-2 py-4 text-[11px] text-textMuted">
              <Loader2 size={12} className="animate-spin text-cyan" />
              Llama 3.3 analizeaza flota...
            </div>
          )}
          {error && (
            <div className="rounded-lg border border-danger/30 bg-danger/10 px-2.5 py-2 text-[11px] text-danger">
              {error}
            </div>
          )}
          {!loading && !error && insights.length === 0 && (
            <p className="px-2 py-4 text-center text-[11px] text-textDim">
              Nimic notabil.
            </p>
          )}
          {insights.map((ins, i) => {
            const cfg = ICONS[ins.icon] ?? ICONS.info
            const { Icon, color, ring } = cfg
            return (
              <div
                key={i}
                className={`rounded-lg border border-border/50 bg-bg/40 p-2.5 ring-1 ${ring}`}
              >
                <div className="flex items-start gap-2">
                  <Icon size={13} className={`mt-0.5 shrink-0 ${color}`} />
                  <div className="min-w-0 flex-1">
                    <p className={`font-display text-[11px] font-bold tracking-wider ${color}`}>
                      {ins.title}
                    </p>
                    <p className="mt-0.5 text-[11px] leading-relaxed text-white">
                      {ins.body}
                    </p>
                  </div>
                </div>
              </div>
            )
          })}
          {generatedAt && (
            <p className="pt-1 text-center text-[9px] text-textDim">
              Generat la{' '}
              {new Date(generatedAt).toLocaleTimeString('ro-RO', {
                hour: '2-digit',
                minute: '2-digit',
              })}{' '}
              · Llama 3.3 70B
            </p>
          )}
        </div>
      )}
    </aside>
  )
}
