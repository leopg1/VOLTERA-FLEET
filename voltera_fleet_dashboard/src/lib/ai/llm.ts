import Groq from 'groq-sdk'

// Llama 3.3 70B — cel mai bun la romana din free tier-ul Groq.
// Alternativa rapida: 'llama-3.1-8b-instant' (jumatate de quality, dublu rapid).
const MODEL_ID = 'llama-3.3-70b-versatile'

let client: Groq | null = null

function getClient(): Groq {
  if (client) return client
  const key = process.env.GROQ_API_KEY
  if (!key) {
    throw new Error(
      'GROQ_API_KEY lipseste din environment. ' +
        'Obtine o cheie gratuita (fara card) la https://console.groq.com/keys ' +
        'si adaug-o in .env.local.',
    )
  }
  client = new Groq({ apiKey: key })
  return client
}

export type ChatTurn = { role: 'user' | 'model'; text: string }

export async function generateText(opts: {
  system: string
  user: string
  history?: ChatTurn[]
  temperature?: number
  maxTokens?: number
  jsonMode?: boolean
}): Promise<string> {
  const messages: Groq.Chat.ChatCompletionMessageParam[] = [
    { role: 'system', content: opts.system },
  ]
  for (const t of opts.history ?? []) {
    messages.push({
      role: t.role === 'model' ? 'assistant' : 'user',
      content: t.text,
    })
  }
  messages.push({ role: 'user', content: opts.user })

  const res = await getClient().chat.completions.create({
    model: MODEL_ID,
    messages,
    temperature: opts.temperature ?? 0.4,
    max_tokens: opts.maxTokens ?? 800,
    ...(opts.jsonMode ? { response_format: { type: 'json_object' } } : {}),
  })

  return res.choices[0]?.message?.content ?? ''
}

export function isConfigured(): boolean {
  return Boolean(process.env.GROQ_API_KEY)
}
