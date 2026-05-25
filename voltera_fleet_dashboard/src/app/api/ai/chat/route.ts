import { NextResponse } from 'next/server'
import { generateText, isConfigured, type ChatTurn } from '@/lib/ai/llm'
import { getFleetSnapshot, snapshotToMarkdown } from '@/lib/ai/context'
import { SYSTEM_COPILOT } from '@/lib/ai/prompts'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

type Body = {
  message: string
  history?: ChatTurn[]
}

export async function POST(req: Request) {
  if (!isConfigured()) {
    return NextResponse.json(
      { error: 'GROQ_API_KEY nu e setat in .env.local' },
      { status: 503 },
    )
  }

  let body: Body
  try {
    body = (await req.json()) as Body
  } catch {
    return NextResponse.json({ error: 'JSON invalid' }, { status: 400 })
  }
  const message = (body.message ?? '').trim()
  if (!message) {
    return NextResponse.json({ error: 'message lipseste' }, { status: 400 })
  }

  try {
    const snap = await getFleetSnapshot({ eventLimit: 20, tripLimit: 8 })
    const context = snapshotToMarkdown(snap)
    const user = `Context (stare actuala a flotei):\n\n${context}\n\n---\n\nIntrebare dispecer: ${message}`

    const reply = await generateText({
      system: SYSTEM_COPILOT,
      user,
      history: body.history ?? [],
      temperature: 0.4,
      maxTokens: 600,
    })

    return NextResponse.json({ reply })
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'eroare necunoscuta'
    return NextResponse.json({ error: msg }, { status: 500 })
  }
}
