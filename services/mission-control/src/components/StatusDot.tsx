import type { ServiceStatus } from '../api.ts'

const MAP: Record<ServiceStatus, { color: string; label: string; pulse: boolean }> = {
  up: { color: 'var(--color-accent)', label: 'ONLINE', pulse: false },
  starting: { color: 'var(--color-warn)', label: 'BOOTING', pulse: true },
  degraded: { color: 'var(--color-danger)', label: 'DEGRADED', pulse: true },
  down: { color: 'var(--color-danger)', label: 'DOWN', pulse: true },
  absent: { color: '#4a4a5a', label: 'ABSENT', pulse: false },
}

export function statusMeta(status: ServiceStatus) {
  return MAP[status]
}

export default function StatusDot({ status, size = 8 }: { status: ServiceStatus; size?: number }) {
  const m = MAP[status]
  return (
    <span
      className={m.pulse ? 'pulse' : ''}
      style={{
        display: 'inline-block',
        width: size,
        height: size,
        borderRadius: '50%',
        background: m.color,
        boxShadow: `0 0 8px ${m.color}`,
      }}
      title={m.label}
    />
  )
}
