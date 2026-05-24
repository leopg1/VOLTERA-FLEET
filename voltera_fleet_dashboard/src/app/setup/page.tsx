import { AlertTriangle, CheckCircle2, ExternalLink } from 'lucide-react'

export const dynamic = 'force-dynamic'

/**
 * Pagina afisata cand env vars Supabase lipsesc. Middleware-ul redirect-eaza
 * automat aici in loc sa crashe-asca cu 500 MIDDLEWARE_INVOCATION_FAILED.
 *
 * Ofera utilizatorului pasi clari pentru a configura Vercel.
 */
export default function SetupPage() {
  const hasUrl = !!process.env.NEXT_PUBLIC_SUPABASE_URL
  const hasKey = !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  return (
    <main className="relative min-h-screen w-screen overflow-hidden bg-bg text-white">
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute -top-1/3 left-1/4 h-[60vmax] w-[60vmax] -translate-x-1/2 rounded-full bg-warn/10 blur-[120px]" />
        <div className="absolute -bottom-1/3 right-1/4 h-[55vmax] w-[55vmax] translate-x-1/2 rounded-full bg-cyan-deep/15 blur-[120px]" />
      </div>

      <div className="relative z-10 mx-auto max-w-2xl px-6 py-12">
        <header className="mb-8 flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-warn/15 ring-1 ring-warn/40">
            <AlertTriangle className="text-warn" size={20} />
          </div>
          <div>
            <h1 className="font-display text-2xl font-black tracking-[0.16em]">
              VOLTERA <span className="text-cyan">FLEET</span>
            </h1>
            <p className="text-xs text-textDim">Setup necesar</p>
          </div>
        </header>

        <div className="overflow-hidden rounded-2xl border border-warn/40 bg-surface/80 backdrop-blur-xl">
          <div className="border-b border-warn/30 bg-warn/5 px-6 py-4">
            <h2 className="font-display text-base font-black tracking-wider text-warn">
              CONFIGURARE INCOMPLETA
            </h2>
            <p className="mt-1 text-sm text-textMuted">
              Aplicatia are nevoie de credentialele Supabase ca sa porneasca.
              Le adaugi in Vercel ca Environment Variables, apoi redeployezi.
            </p>
          </div>

          <div className="space-y-4 p-6">
            <EnvStatus
              name="NEXT_PUBLIC_SUPABASE_URL"
              ok={hasUrl}
              hint="ex: https://abcdefg.supabase.co"
            />
            <EnvStatus
              name="NEXT_PUBLIC_SUPABASE_ANON_KEY"
              ok={hasKey}
              hint="JWT lung (anon public key, NU service_role)"
            />
          </div>

          <div className="border-t border-border/60 bg-bg/40 p-6">
            <h3 className="mb-3 font-display text-sm font-black tracking-widest text-cyan">
              PASII DE URMAT
            </h3>
            <ol className="space-y-3 text-sm text-textMuted">
              <Step n={1}>
                Deschide{' '}
                <a
                  className="inline-flex items-center gap-1 text-cyan hover:underline"
                  href="https://supabase.com/dashboard"
                  target="_blank"
                  rel="noreferrer"
                >
                  Supabase Dashboard
                  <ExternalLink size={12} />
                </a>{' '}
                → proiectul tau → <b>Project Settings</b> → <b>API</b>.
              </Step>
              <Step n={2}>
                Copiaza <b>Project URL</b> si <b>anon public key</b>.
              </Step>
              <Step n={3}>
                In Vercel:{' '}
                <a
                  className="inline-flex items-center gap-1 text-cyan hover:underline"
                  href="https://vercel.com/dashboard"
                  target="_blank"
                  rel="noreferrer"
                >
                  Dashboard
                  <ExternalLink size={12} />
                </a>{' '}
                → proiectul Voltera → <b>Settings</b> →{' '}
                <b>Environment Variables</b>.
              </Step>
              <Step n={4}>
                Adauga ambele variabile pentru{' '}
                <code className="rounded bg-surfaceHi px-1.5 py-0.5 text-cyan">
                  Production
                </code>
                ,{' '}
                <code className="rounded bg-surfaceHi px-1.5 py-0.5 text-cyan">
                  Preview
                </code>{' '}
                si{' '}
                <code className="rounded bg-surfaceHi px-1.5 py-0.5 text-cyan">
                  Development
                </code>{' '}
                (bifeaza toate trei).
              </Step>
              <Step n={5}>
                Tab-ul <b>Deployments</b> → ultimul deployment → meniu
                &quot;...&quot; → <b>Redeploy</b> (debifeaza &quot;Use
                existing Build Cache&quot;).
              </Step>
              <Step n={6}>
                Cand redeploy termina, deschide din nou domeniul. Ar trebui
                sa intri pe <code className="text-cyan">/login</code>.
              </Step>
            </ol>
          </div>
        </div>

        <p className="mt-6 text-center text-xs text-textDim">
          Voltera Fleet · ICE USV ·{' '}
          <a
            href="https://github.com/leopg1/Voltera"
            className="text-cyan hover:underline"
          >
            github.com/leopg1/Voltera
          </a>
        </p>
      </div>
    </main>
  )
}

function EnvStatus({
  name,
  ok,
  hint,
}: {
  name: string
  ok: boolean
  hint: string
}) {
  return (
    <div
      className={`flex items-start gap-3 rounded-lg border p-3 ${
        ok
          ? 'border-ok/30 bg-ok/5'
          : 'border-danger/30 bg-danger/5'
      }`}
    >
      {ok ? (
        <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-ok" />
      ) : (
        <AlertTriangle size={18} className="mt-0.5 shrink-0 text-danger" />
      )}
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <code className="font-mono text-xs text-white">{name}</code>
          <span
            className={`rounded px-1.5 py-0.5 font-display text-[9px] font-black tracking-widest ${
              ok ? 'bg-ok/20 text-ok' : 'bg-danger/20 text-danger'
            }`}
          >
            {ok ? 'OK' : 'LIPSA'}
          </span>
        </div>
        <p className="mt-0.5 text-xs text-textMuted">{hint}</p>
      </div>
    </div>
  )
}

function Step({ n, children }: { n: number; children: React.ReactNode }) {
  return (
    <li className="flex gap-3">
      <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-cyan/15 font-display text-[11px] font-black text-cyan ring-1 ring-cyan/30">
        {n}
      </span>
      <div className="flex-1 leading-relaxed">{children}</div>
    </li>
  )
}
