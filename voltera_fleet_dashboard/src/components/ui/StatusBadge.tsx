type Status = 'driving' | 'idle' | 'alert' | 'offline'

const STYLES: Record<Status, string> = {
  driving: 'border-ok/50 bg-ok/10 text-ok',
  idle: 'border-warn/50 bg-warn/10 text-warn',
  alert: 'border-danger/50 bg-danger/10 text-danger',
  offline: 'border-border/60 bg-surface/40 text-textMuted',
}

export default function StatusBadge({ status }: { status: Status }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 font-display text-[10px] font-bold tracking-widest ${STYLES[status]}`}
    >
      <span
        className="h-1.5 w-1.5 rounded-full"
        style={{ background: 'currentColor', boxShadow: '0 0 6px currentColor' }}
      />
      {status.toUpperCase()}
    </span>
  )
}
