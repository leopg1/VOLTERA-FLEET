import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/shell/Sidebar'
import Topbar from '@/components/shell/Topbar'

// Toate paginile sub (app) sunt autentificate si fetch-uiesc per-request din
// Supabase. Le marcam ca dynamic, altfel Next incearca prerender la build,
// moment in care env vars Supabase nu sunt disponibile pe Vercel.
export const dynamic = 'force-dynamic'

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-bg text-white">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar
          email={user.email ?? '—'}
          displayName={
            (user.user_metadata?.full_name as string | undefined) ??
            user.email?.split('@')[0] ??
            'Dispecer'
          }
        />
        <main className="relative min-w-0 flex-1 overflow-hidden">
          {children}
        </main>
      </div>
    </div>
  )
}
