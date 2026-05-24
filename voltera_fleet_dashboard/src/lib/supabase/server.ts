import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

/**
 * Server-side Supabase client.
 * Apeleaza-l in Server Components, Server Actions si Route Handlers.
 *
 * Daca env vars Supabase nu sunt configurate, aruncam o eroare prietenoasa
 * cu instructiuni clare in loc sa lasam @supabase/ssr sa explodeze cu
 * un mesaj generic.
 */
export function createClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!url || !anonKey) {
    throw new Error(
      'Voltera nu poate porni: lipsesc NEXT_PUBLIC_SUPABASE_URL ' +
        'si/sau NEXT_PUBLIC_SUPABASE_ANON_KEY din environment. ' +
        'Pe Vercel: Project Settings → Environment Variables → ' +
        'adauga ambele variabile la Production + Preview, apoi Redeploy.',
    )
  }

  const cookieStore = cookies()
  return createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          )
        } catch {
          // Server Components nu pot seta cookies — middleware-ul o face.
        }
      },
    },
  })
}
