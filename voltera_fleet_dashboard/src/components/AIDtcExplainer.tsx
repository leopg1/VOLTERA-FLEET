'use client'

import { useState } from 'react'
import { Sparkles, Loader2, Wrench, AlertTriangle, Activity } from 'lucide-react'
import type { DtcExplanation } from '@/app/api/ai/explain-dtc/route'

type Props = {
  code: string
  plate?: string
  make?: string
  model?: string
  title?: string
  description?: string
}

export default function AIDtcExplainer(props: Props) {
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [data, setData] = useState<DtcExplanation | null>(null)

  async function load() {
    if (data || loading) {
      setOpen((o) => !o)
      return
    }
    setOpen(true)
    setLoading(true)
    setError(null)
    try {
      const res = await fetch('/api/ai/explain-dtc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: props.code,
          context: {
            plate: props.plate,
            make: props.make,
            model: props.model,
            title: props.title,
            description: props.description,
          },
        }),
      })
      const json = (await res.json()) as DtcExplanation & { error?: string }
      if (!res.ok) throw new Error(json.error ?? `HTTP ${res.status}`)
      setData(json)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'eroare necunoscuta')
    } finally {
      setLoading(false)
    }
  }

  const sevColor =
    data?.severitate === 'high'
      ? 'text-danger border-danger/40 bg-danger/10'
      : data?.severitate === 'medium'
        ? 'text-warn border-warn/40 bg-warn/10'
        : 'text-ok border-ok/40 bg-ok/10'

  return (
    <div className="mt-2">
      <button
        type="button"
        onClick={load}
        className="inline-flex items-center gap-1.5 rounded-lg border border-cyan/40 bg-cyan/10 px-2.5 py-1 font-display text-[10px] font-bold tracking-widest text-cyan transition hover:bg-cyan/20"
      >
        <Sparkles size={11} />
        {open && data ? 'ASCUNDE EXPLICATIA' : 'EXPLICA CU AI'}
      </button>

      {open && (
        <div className="mt-2 rounded-xl border border-cyan/30 bg-gradient-to-br from-cyan/5 to-transparent p-3 text-[12px]">
          {loading && (
            <div className="flex items-center gap-2 text-textMuted">
              <Loader2 size={12} className="animate-spin text-cyan" />
              Llama 3.3 analizeaza codul {props.code}...
            </div>
          )}
          {error && (
            <div className="text-danger">Eroare: {error}</div>
          )}
          {data && !loading && (
            <div className="space-y-2.5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-display text-[11px] font-black tracking-widest text-cyan">
                    {data.code}
                  </p>
                  <p className="mt-0.5 text-white">{data.nume}</p>
                </div>
                <span
                  className={`shrink-0 rounded border px-2 py-0.5 font-display text-[9px] font-bold tracking-widest ${sevColor}`}
                >
                  {data.severitate === 'high'
                    ? 'CRITIC'
                    : data.severitate === 'medium'
                      ? 'MEDIU'
                      : 'MINOR'}
                </span>
              </div>

              {data.cauze_probabile?.length > 0 && (
                <Section
                  icon={<AlertTriangle size={11} className="text-warn" />}
                  title="CAUZE PROBABILE"
                  items={data.cauze_probabile}
                />
              )}
              {data.simptome?.length > 0 && (
                <Section
                  icon={<Activity size={11} className="text-cyan" />}
                  title="SIMPTOME"
                  items={data.simptome}
                />
              )}
              {data.actiuni_recomandate?.length > 0 && (
                <Section
                  icon={<Wrench size={11} className="text-ok" />}
                  title="ACTIUNI RECOMANDATE"
                  items={data.actiuni_recomandate}
                />
              )}
              {data.cost_estimat_ron && (
                <p className="text-[11px] text-textMuted">
                  Cost estimat reparatie:{' '}
                  <span className="font-mono text-white">
                    {data.cost_estimat_ron} RON
                  </span>
                </p>
              )}
              <p className="text-[10px] text-textDim">
                Generat de Llama 3.3 (Groq) · informativ, nu inlocuieste diagnoza service.
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

function Section({
  icon,
  title,
  items,
}: {
  icon: React.ReactNode
  title: string
  items: string[]
}) {
  return (
    <div>
      <p className="mb-1 flex items-center gap-1.5 font-display text-[9px] font-bold tracking-widest text-textMuted">
        {icon}
        {title}
      </p>
      <ul className="space-y-0.5 pl-1">
        {items.map((it, i) => (
          <li key={i} className="flex gap-1.5 text-white">
            <span className="text-cyan">·</span>
            <span>{it}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
