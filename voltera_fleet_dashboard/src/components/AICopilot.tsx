'use client'

import { useEffect, useRef, useState } from 'react'
import { Bot, Send, Sparkles, X, Loader2 } from 'lucide-react'

type Turn = { role: 'user' | 'model'; text: string }

const SUGGESTIONS = [
  'Care vehicul are cele mai multe alerte critice?',
  'Ce inseamna codul P0420?',
  'Cine a condus cel mai eficient azi?',
  'Cate trasee s-au facut in ultimele 24h?',
]

export default function AICopilot() {
  const [open, setOpen] = useState(false)
  const [input, setInput] = useState('')
  const [turns, setTurns] = useState<Turn[]>([])
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [turns, sending])

  // Esc inchide panoul
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  async function send(text: string) {
    const message = text.trim()
    if (!message || sending) return
    setError(null)
    const newTurns: Turn[] = [...turns, { role: 'user', text: message }]
    setTurns(newTurns)
    setInput('')
    setSending(true)
    try {
      const res = await fetch('/api/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message,
          history: turns,
        }),
      })
      const data = (await res.json()) as { reply?: string; error?: string }
      if (!res.ok) throw new Error(data.error ?? `HTTP ${res.status}`)
      setTurns([...newTurns, { role: 'model', text: data.reply ?? '' }])
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'eroare necunoscuta'
      setError(msg)
    } finally {
      setSending(false)
    }
  }

  return (
    <>
      {/* Floating launcher */}
      {!open && (
        <button
          type="button"
          onClick={() => setOpen(true)}
          aria-label="Deschide Voltera Copilot"
          className="group fixed bottom-6 right-6 z-50 flex h-14 items-center gap-2 rounded-full border border-cyan/50 bg-bg/90 px-5 font-display text-xs font-black tracking-widest text-cyan shadow-[0_8px_32px_-8px_rgba(0,212,255,0.55)] backdrop-blur-xl transition hover:scale-105 hover:border-cyan hover:bg-cyan/10 hover:shadow-[0_12px_40px_-8px_rgba(0,212,255,0.85)]"
        >
          <span className="relative flex h-8 w-8 items-center justify-center rounded-full bg-cyan/15">
            <Sparkles size={16} className="text-cyan" />
            <span className="absolute -right-0.5 -top-0.5 flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-cyan opacity-60" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-cyan" />
            </span>
          </span>
          AI COPILOT
        </button>
      )}

      {/* Panel */}
      <div
        className={`fixed bottom-6 right-6 z-50 flex w-[min(420px,calc(100vw-3rem))] flex-col overflow-hidden rounded-2xl border border-cyan/40 bg-surface/95 shadow-[0_24px_64px_-12px_rgba(0,0,0,0.9)] backdrop-blur-2xl transition-all duration-200 ease-out ${
          open
            ? 'pointer-events-auto translate-y-0 opacity-100'
            : 'pointer-events-none translate-y-4 opacity-0'
        }`}
        style={{ height: 'min(620px, calc(100vh - 3rem))' }}
        role="dialog"
        aria-label="Voltera AI Copilot"
        aria-hidden={!open}
      >
        {/* Header */}
        <div className="flex shrink-0 items-center gap-3 border-b border-cyan/20 bg-gradient-to-r from-cyan/10 to-transparent px-4 py-3">
          <div className="relative flex h-9 w-9 items-center justify-center rounded-lg bg-cyan/15 ring-1 ring-cyan/40">
            <Bot size={18} className="text-cyan" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-display text-sm font-black tracking-wider text-white">
              VOLTERA COPILOT
            </p>
            <p className="font-display text-[10px] font-bold tracking-widest text-cyan">
              LLAMA 3.3 · STARE FLOTA IN TIMP REAL
            </p>
          </div>
          <button
            type="button"
            onClick={() => setOpen(false)}
            aria-label="Inchide"
            className="rounded-md p-1.5 text-textMuted transition hover:bg-surface hover:text-white"
          >
            <X size={16} />
          </button>
        </div>

        {/* Mesaje */}
        <div
          ref={scrollRef}
          className="flex-1 space-y-3 overflow-y-auto px-4 py-4"
        >
          {turns.length === 0 && (
            <div className="space-y-3">
              <p className="text-xs text-textMuted">
                Intreaba-ma orice despre flota. Vad in timp real vehiculele,
                evenimentele si traseele.
              </p>
              <div className="space-y-1.5">
                {SUGGESTIONS.map((s) => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => send(s)}
                    className="block w-full rounded-lg border border-border/60 bg-surface/40 px-3 py-2 text-left text-xs text-textMuted transition hover:border-cyan/40 hover:bg-cyan/5 hover:text-white"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          )}
          {turns.map((t, i) => (
            <Bubble key={i} role={t.role} text={t.text} />
          ))}
          {sending && (
            <div className="flex items-center gap-2 text-xs text-textMuted">
              <Loader2 size={14} className="animate-spin text-cyan" />
              <span>Copilot gandeste...</span>
            </div>
          )}
          {error && (
            <div className="rounded-lg border border-danger/40 bg-danger/10 px-3 py-2 text-xs text-danger">
              {error}
            </div>
          )}
        </div>

        {/* Composer */}
        <form
          onSubmit={(e) => {
            e.preventDefault()
            send(input)
          }}
          className="flex shrink-0 items-center gap-2 border-t border-border/60 bg-bg/50 p-3"
        >
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Intreaba despre flota, DTC, soferi..."
            disabled={sending}
            className="flex-1 rounded-lg border border-border/60 bg-surface/60 px-3 py-2 text-sm text-white placeholder:text-textDim focus:border-cyan/60 focus:outline-none disabled:opacity-50"
          />
          <button
            type="submit"
            disabled={sending || !input.trim()}
            aria-label="Trimite"
            className="flex h-9 w-9 items-center justify-center rounded-lg border border-cyan/40 bg-cyan/15 text-cyan transition hover:bg-cyan/25 disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Send size={14} />
          </button>
        </form>
      </div>
    </>
  )
}

function Bubble({ role, text }: { role: 'user' | 'model'; text: string }) {
  const isUser = role === 'user'
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[85%] whitespace-pre-wrap rounded-2xl px-3.5 py-2 text-sm leading-relaxed ${
          isUser
            ? 'rounded-br-sm bg-cyan/15 text-white ring-1 ring-cyan/30'
            : 'rounded-bl-sm bg-surface/80 text-white ring-1 ring-border/60'
        }`}
      >
        {renderInline(text)}
      </div>
    </div>
  )
}

// Render minim de markdown inline: **bold** + bullete "- "
function renderInline(text: string): React.ReactNode {
  const lines = text.split('\n')
  return lines.map((line, i) => {
    const isBullet = /^\s*-\s+/.test(line)
    const stripped = isBullet ? line.replace(/^\s*-\s+/, '') : line
    const parts = stripped.split(/(\*\*[^*]+\*\*)/g).map((part, j) => {
      if (/^\*\*[^*]+\*\*$/.test(part)) {
        return (
          <strong key={j} className="font-bold text-cyan">
            {part.slice(2, -2)}
          </strong>
        )
      }
      return <span key={j}>{part}</span>
    })
    return (
      <div key={i} className={isBullet ? 'flex gap-2' : undefined}>
        {isBullet && <span className="text-cyan">•</span>}
        <span className="flex-1">{parts}</span>
      </div>
    )
  })
}
