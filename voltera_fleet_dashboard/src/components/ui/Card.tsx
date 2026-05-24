/**
 * Card glass — primitiva pentru toate panourile.
 */
export function Card({
  children,
  className = '',
}: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <div
      className={`rounded-2xl border border-border/60 bg-surface/60 backdrop-blur-md ${className}`}
    >
      {children}
    </div>
  )
}

export function CardHeader({
  title,
  subtitle,
  right,
}: {
  title: string
  subtitle?: string
  right?: React.ReactNode
}) {
  return (
    <div className="flex items-center justify-between border-b border-border/60 px-5 py-3">
      <div>
        <h3 className="font-display text-[11px] font-black tracking-widest text-textMuted">
          {title}
        </h3>
        {subtitle && (
          <p className="mt-0.5 text-[10px] text-textDim">{subtitle}</p>
        )}
      </div>
      {right}
    </div>
  )
}

export function StatCard({
  label,
  value,
  unit,
  trend,
  color = 'cyan',
  icon,
}: {
  label: string
  value: string | number
  unit?: string
  trend?: string
  color?: 'cyan' | 'ok' | 'warn' | 'danger'
  icon?: React.ReactNode
}) {
  const colorCls = {
    cyan: 'text-cyan',
    ok: 'text-ok',
    warn: 'text-warn',
    danger: 'text-danger',
  }[color]
  return (
    <div className="rounded-2xl border border-border/60 bg-surface/60 p-5 backdrop-blur-md transition hover:border-cyan/30 hover:bg-surface/80">
      <div className="flex items-start justify-between">
        <div>
          <p className="font-display text-[10px] font-bold tracking-widest text-textMuted">
            {label}
          </p>
          <p className="mt-2 font-display text-3xl font-black tracking-tight text-white">
            {value}
            {unit && (
              <span className="ml-1 text-sm font-medium text-textMuted">
                {unit}
              </span>
            )}
          </p>
          {trend && (
            <p className="mt-1 text-[11px] text-textDim">{trend}</p>
          )}
        </div>
        {icon && (
          <div className={`rounded-lg bg-bg/60 p-2 ${colorCls}`}>{icon}</div>
        )}
      </div>
    </div>
  )
}
