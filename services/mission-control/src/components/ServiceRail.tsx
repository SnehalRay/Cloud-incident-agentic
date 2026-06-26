import { useState } from 'react'
import { api, type Service } from '../api.ts'
import HudFrame from './HudFrame.tsx'
import StatusDot, { statusMeta } from './StatusDot.tsx'

const KIND_LABEL: Record<Service['kind'], string> = {
  app: 'APP',
  data: 'DATA',
  queue: 'QUEUE',
  observability: 'OBSERV',
  agent: 'AGENT',
}

const KIND_COLOR: Record<Service['kind'], string> = {
  app: 'text-accent',
  data: 'text-info',
  queue: 'text-active',
  observability: 'text-warn',
  agent: 'text-dim',
}

interface Props {
  services: Service[]
  loading: boolean
  onChanged: () => void
}

export default function ServiceRail({ services, loading, onChanged }: Props) {
  const [busy, setBusy] = useState<string | null>(null)

  async function toggle(svc: Service) {
    const action = svc.status === 'down' || svc.status === 'absent' ? 'start' : 'stop'
    setBusy(svc.id)
    try {
      await api.serviceAction(svc.id, action)
      // give docker a beat, then refresh
      setTimeout(onChanged, 600)
    } finally {
      setBusy(null)
    }
  }

  const online = services.filter((s) => s.status === 'up').length

  return (
    <HudFrame
      title="Infrastructure"
      tone="accent"
      accessory={
        <span className="font-mono text-[10px] text-dim">
          <span className="text-accent">{online}</span>/{services.length} UP
        </span>
      }
      bodyClassName="overflow-y-auto"
    >
      <ul className="flex flex-col">
        {services.length === 0 && (
          <li className="px-3 py-6 text-center font-mono text-[11px] text-dim">
            {loading ? 'scanning fleet…' : 'no services — is the stack up? (make up)'}
          </li>
        )}
        {services.map((svc) => {
          const meta = statusMeta(svc.status)
          const isBusy = busy === svc.id
          const isDown = svc.status === 'down' || svc.status === 'absent'
          return (
            <li
              key={svc.id}
              className="group flex items-center gap-3 border-b border-edge/40 px-3 py-2 hover:bg-muted/30"
            >
              <StatusDot status={svc.status} />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="truncate font-mono text-[13px] text-fg">{svc.label}</span>
                  <span className={`title text-[8px] ${KIND_COLOR[svc.kind]} opacity-70`}>
                    {KIND_LABEL[svc.kind]}
                  </span>
                </div>
                <div className="truncate font-mono text-[10px] text-dim">{svc.role}</div>
              </div>
              {svc.controllable ? (
                <button
                  disabled={isBusy || svc.status === 'starting'}
                  onClick={() => toggle(svc)}
                  className={`chamfer-sm shrink-0 border px-2 py-1 font-mono text-[9px] tracking-wider transition disabled:opacity-40 ${
                    isDown
                      ? 'border-accent/50 text-accent hover:bg-accent/10'
                      : 'border-danger/50 text-danger hover:bg-danger/10'
                  }`}
                  title={isDown ? 'Start container' : 'Stop container'}
                >
                  {isBusy ? '···' : isDown ? 'START' : 'STOP'}
                </button>
              ) : (
                <span
                  className="shrink-0 font-mono text-[8px] tracking-wider text-dim"
                  title={meta.label}
                >
                  {meta.label}
                </span>
              )}
            </li>
          )
        })}
      </ul>
    </HudFrame>
  )
}
