import { NextResponse } from 'next/server'
import { generateText, isConfigured } from '@/lib/ai/llm'
import { getFleetSnapshot, snapshotToMarkdown } from '@/lib/ai/context'
import { SYSTEM_INSIGHTS } from '@/lib/ai/prompts'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

export type Insight = {
  icon: 'alert' | 'ok' | 'info' | 'warn'
  title: string
  body: string
}

function stripJsonFences(s: string): string {
  return s
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```$/i, '')
    .trim()
}

export async function GET() {
  if (!isConfigured()) {
    return NextResponse.json(
      { error: 'GROQ_API_KEY nu e setat in .env.local' },
      { status: 503 },
    )
  }

  try {
    const snap = await getFleetSnapshot({ eventLimit: 30, tripLimit: 15 })
    const context = snapshotToMarkdown(snap)
    const raw = await generateText({
      system: SYSTEM_INSIGHTS,
      user: context,
      temperature: 0.3,
      maxTokens: 500,
      jsonMode: true,
    })
    let parsed: { insights: Insight[] }
    try {
      parsed = JSON.parse(stripJsonFences(raw)) as { insights: Insight[] }
    } catch {
      return NextResponse.json(
        { error: 'modelul nu a returnat JSON valid', raw },
        { status: 502 },
      )
    }
    return NextResponse.json({
      generatedAt: new Date().toISOString(),
      insights: parsed.insights ?? [],
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'eroare necunoscuta'
    return NextResponse.json({ error: msg }, { status: 500 })
  }
}
