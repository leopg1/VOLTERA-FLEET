import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Auth middleware — verifica sesiunea pe fiecare request si redirecteaza
 * spre /login daca user-ul nu e autentificat.
 *
 * Publice (fara auth):
 *   /login, /setup
 *   /_next/*, /favicon.ico
 */
export async function updateSession(request: NextRequest) {
  // ----- Demo bypass -----
  // Sare peste auth daca NEXT_PUBLIC_DEMO_MODE=true. Util cand backend-ul
  // Supabase nu e reachable (network blocat, proiect pe pauza, etc).
  // NU folosi in productie — ofera acces fara autentificare.
  if (process.env.NEXT_PUBLIC_DEMO_MODE === 'true') {
    if (request.nextUrl.pathname.startsWith('/login')) {
      const home = request.nextUrl.clone()
      home.pathname = '/'
      return NextResponse.redirect(home)
    }
    return NextResponse.next({ request })
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  // Env vars lipsa — nu putem face auth. In loc sa crashe-asca middleware
  // (rezultand 500 MIDDLEWARE_INVOCATION_FAILED), redirectam catre /setup
  // care arata clar ce env vars trebuie configurate in Vercel.
  if (!url || !anonKey) {
    const isSetupPage = request.nextUrl.pathname.startsWith('/setup')
    const isAsset =
      request.nextUrl.pathname.startsWith('/_next') ||
      request.nextUrl.pathname === '/favicon.ico'
    if (isSetupPage || isAsset) return NextResponse.next({ request })
    const redirect = request.nextUrl.clone()
    redirect.pathname = '/setup'
    return NextResponse.redirect(redirect)
  }

  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        )
        supabaseResponse = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options),
        )
      },
    },
  })

  let user: { id: string } | null = null
  try {
    const res = await supabase.auth.getUser()
    user = res.data.user
  } catch {
    // Daca Supabase nu raspunde (URL gresit, network), tratam ca neautentificat.
    user = null
  }

  const isLoginPage = request.nextUrl.pathname.startsWith('/login')
  const isSetupPage = request.nextUrl.pathname.startsWith('/setup')
  const isPublicAsset =
    request.nextUrl.pathname.startsWith('/_next') ||
    request.nextUrl.pathname === '/favicon.ico'

  // Neautentificat → forteaza /login
  if (!user && !isLoginPage && !isSetupPage && !isPublicAsset) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  // Deja logat → nu permite re-acces la /login
  if (user && isLoginPage) {
    const url = request.nextUrl.clone()
    url.pathname = '/'
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}
