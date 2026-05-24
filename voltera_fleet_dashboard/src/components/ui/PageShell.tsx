'use client'

/**
 * Container standard pentru paginile interioare (non-dashboard).
 * Asigura padding, header consistent, scroll lin.
 */
export default function PageShell({
  title,
  subtitle,
  actions,
  children,
}: {
  title: string
  subtitle?: string
  actions?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-[1400px] px-8 pb-10 pt-6">
        <div className="mb-6 flex items-end justify-between gap-4">
          <div>
            <h1 className="font-display text-2xl font-black tracking-[0.05em] text-white">
              {title}
            </h1>
            {subtitle && (
              <p className="mt-1 text-sm text-textMuted">{subtitle}</p>
            )}
          </div>
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
        {children}
      </div>
    </div>
  )
}
