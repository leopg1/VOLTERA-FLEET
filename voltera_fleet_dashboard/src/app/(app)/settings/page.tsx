import { createClient } from '@/lib/supabase/server'
import PageShell from '@/components/ui/PageShell'
import { Card, CardHeader } from '@/components/ui/Card'
import { signOut } from '@/app/login/actions'
import {
  User as UserIcon,
  Mail,
  KeyRound,
  Cloud,
  Database,
  ShieldCheck,
  LogOut,
} from 'lucide-react'

export default async function SettingsPage() {
  const demoMode = process.env.NEXT_PUBLIC_DEMO_MODE === 'true'

  let user: {
    id?: string
    email?: string | null
    user_metadata?: { full_name?: string }
    last_sign_in_at?: string | null
  } | null = null

  if (!demoMode) {
    try {
      const supabase = createClient()
      const result = await supabase.auth.getUser()
      user = result.data.user
    } catch {
      user = null
    }
  } else {
    user = {
      email: 'demo@voltera.local',
      user_metadata: { full_name: 'Demo Dispecer' },
    }
  }

  const displayName =
    (user?.user_metadata?.full_name as string | undefined) ??
    user?.email?.split('@')[0] ??
    'Dispecer'

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '—'
  const projectRef =
    supabaseUrl.match(/https?:\/\/([^.]+)\.supabase\.co/)?.[1] ?? '—'

  return (
    <PageShell
      title="Setari"
      subtitle="Profilul tau de dispecer + infrastructura conectata"
    >
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Profil */}
        <Card className="lg:col-span-2">
          <CardHeader title="PROFIL DISPECER" subtitle="contul tau de acces" />
          <div className="p-5">
            <div className="flex items-center gap-4">
              <div className="grid h-16 w-16 place-items-center rounded-full bg-gradient-to-br from-cyan to-cyan-deep font-display text-xl font-black text-bg">
                {displayName
                  .split(/\s+/)
                  .map((p) => p[0])
                  .filter(Boolean)
                  .slice(0, 2)
                  .join('')
                  .toUpperCase()}
              </div>
              <div>
                <p className="font-display text-xl font-black text-white">
                  {displayName}
                </p>
                <p className="text-sm text-textMuted">
                  {user?.email ?? '—'}
                </p>
                <p className="mt-1 text-[11px] uppercase tracking-widest text-cyan">
                  Voltera Fleet · Dispatcher
                </p>
              </div>
            </div>

            <div className="mt-6 space-y-3">
              <Field
                icon={<Mail size={14} />}
                label="EMAIL"
                value={user?.email ?? '—'}
              />
              <Field
                icon={<UserIcon size={14} />}
                label="UID"
                value={user?.id ? user.id.slice(0, 18) + '…' : '—'}
                mono
              />
              <Field
                icon={<KeyRound size={14} />}
                label="ULTIMA AUTENTIFICARE"
                value={
                  user?.last_sign_in_at
                    ? new Date(user.last_sign_in_at).toLocaleString('ro-RO')
                    : '—'
                }
              />
              <Field
                icon={<ShieldCheck size={14} />}
                label="ROL"
                value="dispatcher"
              />
            </div>
          </div>
        </Card>

        {/* Conexiune */}
        <Card>
          <CardHeader title="INFRASTRUCTURA" subtitle="Supabase project" />
          <div className="space-y-3 p-5">
            <Field
              icon={<Database size={14} />}
              label="PROJECT REF"
              value={projectRef}
              mono
            />
            <Field
              icon={<Cloud size={14} />}
              label="REGIUNE"
              value="eu-central-1 · Frankfurt"
            />
            <div className="mt-4 rounded-lg border border-ok/30 bg-ok/5 p-3">
              <p className="font-display text-[10px] font-bold tracking-widest text-ok">
                ✓ REALTIME ACTIVAT
              </p>
              <p className="mt-1 text-[11px] text-textMuted">
                telemetry_samples, events, trips
              </p>
            </div>
          </div>
        </Card>

        {/* Tableta config */}
        <Card className="lg:col-span-2">
          <CardHeader
            title="TABLETA VOLTERA · CONFIGURARE"
            subtitle="datele pe care le pui in app pe tableta sub MORE → FLEET CLOUD"
          />
          <div className="p-5">
            <ol className="list-inside list-decimal space-y-2 text-sm text-textMuted">
              <li>
                Pe tableta deschide aplicatia <b className="text-white">Voltera</b>
              </li>
              <li>
                Acceseaza <b className="text-white">MORE → FLEET CLOUD</b>
              </li>
              <li>
                Completeaza:
                <ul className="ml-6 mt-2 space-y-1 text-[12px]">
                  <li>
                    <span className="text-textDim">Supabase URL:</span>{' '}
                    <code className="rounded bg-bg/60 px-2 py-0.5 font-mono text-cyan">
                      {supabaseUrl}
                    </code>
                  </li>
                  <li>
                    <span className="text-textDim">Anon Key:</span>{' '}
                    <span className="text-textMuted">
                      (vezi <code className="text-cyan">.env.local</code>)
                    </span>
                  </li>
                  <li>
                    <span className="text-textDim">Vehicle ID:</span> UUID-ul
                    masinii din tabelul <code className="text-cyan">vehicles</code>
                  </li>
                </ul>
              </li>
              <li>
                Apasa <b className="text-white">SALVEAZA & ACTIVEAZA</b>. GPS-ul
                se activeaza automat → sample-urile ajung in dashboard la &lt;
                1s.
              </li>
            </ol>
          </div>
        </Card>

        {/* Sign out */}
        <Card>
          <CardHeader title="SESIUNE" subtitle="autentificare" />
          <div className="p-5">
            <p className="mb-4 text-sm text-textMuted">
              Esti conectat ca <b className="text-white">{displayName}</b>.
              Datele tale Supabase raman salvate cookie-side pentru ~7 zile.
            </p>
            <form action={signOut}>
              <button
                type="submit"
                className="flex w-full items-center justify-center gap-2 rounded-lg border border-danger/40 bg-danger/10 px-4 py-2.5 font-display text-sm font-bold tracking-widest text-danger transition hover:bg-danger/20"
              >
                <LogOut size={14} /> LOGOUT
              </button>
            </form>
          </div>
        </Card>
      </div>
    </PageShell>
  )
}

function Field({
  icon,
  label,
  value,
  mono,
}: {
  icon: React.ReactNode
  label: string
  value: string
  mono?: boolean
}) {
  return (
    <div className="rounded-lg border border-border/60 bg-bg/40 px-4 py-3">
      <div className="flex items-center gap-1.5 text-[10px] font-bold tracking-widest text-textMuted">
        {icon} {label}
      </div>
      <p
        className={`mt-1 break-all text-sm text-white ${
          mono ? 'font-mono tabular-nums' : ''
        }`}
      >
        {value}
      </p>
    </div>
  )
}
