import { NextResponse } from 'next/server'
import { generateText, isConfigured } from '@/lib/ai/llm'
import { SYSTEM_DTC } from '@/lib/ai/prompts'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

type Body = {
  code: string
  context?: {
    plate?: string
    make?: string
    model?: string
    title?: string
    description?: string
  }
}

export type DtcExplanation = {
  code: string
  nume: string
  cauze_probabile: string[]
  simptome: string[]
  actiuni_recomandate: string[]
  severitate: 'low' | 'medium' | 'high'
  cost_estimat_ron: string
}

function stripJsonFences(s: string): string {
  return s
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```$/i, '')
    .trim()
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
  const code = (body.code ?? '').trim().toUpperCase()
  if (!code) {
    return NextResponse.json({ error: 'code lipseste' }, { status: 400 })
  }

  const ctxLines: string[] = []
  if (body.context?.plate) ctxLines.push(`Vehicul: ${body.context.plate}`)
  if (body.context?.make || body.context?.model) {
    ctxLines.push(`Model: ${body.context.make ?? ''} ${body.context.model ?? ''}`.trim())
  }
  if (body.context?.title) ctxLines.push(`Titlu eveniment: ${body.context.title}`)
  if (body.context?.description) ctxLines.push(`Descriere: ${body.context.description}`)

  const user = `Cod DTC: ${code}\n${ctxLines.length ? ctxLines.join('\n') + '\n' : ''}\nGenereaza explicatia in JSON-ul cerut.`

  try {
    const raw = await generateText({
      system: SYSTEM_DTC,
      user,
      temperature: 0.2,
      maxTokens: 600,
      jsonMode: true,
    })
    let parsed: DtcExplanation
    try {
      parsed = JSON.parse(stripJsonFences(raw)) as DtcExplanation
    } catch {
      return NextResponse.json(
        { error: 'modelul nu a returnat JSON valid', raw },
        { status: 502 },
      )
    }
    return NextResponse.json(parsed)
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'eroare necunoscuta'
    return NextResponse.json({ error: msg }, { status: 500 })
  }
}
