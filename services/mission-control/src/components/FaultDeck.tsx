import { useState } from 'react'
import { api, type Fault } from '../api.ts'
import HudFrame from './HudFrame.tsx'

export interface TimelineEntry {
  at: number
  kind: 'fault' | 'traffic' | 'service' | 'agent'
  text: string
  tone: 'accent' | 'info' | 'active' | 'danger'
}

interface Props {
  faults: Fault[]
  active: Set<string>
  onActiveChange: (next: Set<string>) => void
  onLog: (e: TimelineEntry) => void
  onAfterAction: () => void
}

export default function FaultDeck({ faults, active, onActiveChange, onLog, onAfterAction }: Props) {
  const [busy, setBusy] = useState<string | null>(null)

  async function fire(fault: Fault, action: 'trigger' | 'reset') {
    setBusy(fault.id)
    try {
      const r = await api.faultAction(fault.id, action)
      const next = new Set(active)
      if (action === 'trigger') next.add(fault.id)
      else next.delete(fault.id)
      onActiveChange(next)
      onLog({
        at: Date.now(),
        kind: 'fault',
        tone: action === 'trigger' ? 'active' : 'accent',
        text:
          action === 'trigger'
            ? `INJECTED · ${fault.label} → ${fault.target}`
            : `CLEARED · ${fault.label}`,
      })
      if (!r.ok)
        onLog({ at: Date.now(), kind: 'fault', tone: 'danger', text: `${fault.label}: script error` })
      setTimeout(onAfterAction, 600)
    } finally {
      setBusy(null)
    }
  }

  return (
    <HudFrame
      title="Fault Injection"
      tone="active"
      accessory={
        <span className="font-mono text-[10px] text-dim">
          {active.size > 0 ? (
            <span className="text-active glitch">{active.size} ACTIVE</span>
          ) : (
            <span className="text-accent">NOMINAL</span>
          )}
        </span>
      }
      bodyClassName="overflow-y-auto p-2"
    >
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3">
        {faults.map((f) => {
          const isActive = active.has(f.id)
          const isBusy = busy === f.id
          return (
            <article
              key={f.id}
              className={`chamfer-sm relative flex flex-col gap-1.5 border bg-card/70 p-2.5 transition ${
                isActive ? 'border-active/70 glow-active' : 'border-edge hover:border-info/40'
              }`}
            >
              <div className="flex items-start justify-between gap-2">
                <h3 className="title text-[11px] text-fg">{f.label}</h3>
                {isActive && (
                  <span className="title glitch shrink-0 text-[8px] text-active text-glow">●ACTIVE</span>
                )}
              </div>
              <p className="font-mono text-[10px] leading-snug text-dim">{f.blurb}</p>
              <div className="mt-auto flex flex-wrap gap-x-3 gap-y-0.5 font-mono text-[9px] text-dim">
                <span>
                  <span className="text-info">▸</span> {f.target}
                </span>
                <span title="Watch this Grafana signal">
                  <span className="text-warn">◉</span> {f.watch}
                </span>
              </div>
              <div className="mt-1 flex gap-1.5">
                <button
                  disabled={isBusy}
                  onClick={() => fire(f, 'trigger')}
                  className="chamfer-sm flex-1 border border-active/50 py-1 font-mono text-[9px] tracking-wider text-active transition hover:bg-active/10 disabled:opacity-40"
                >
                  {isBusy ? '···' : 'INJECT'}
                </button>
                <button
                  disabled={isBusy}
                  onClick={() => fire(f, 'reset')}
                  className="chamfer-sm flex-1 border border-accent/50 py-1 font-mono text-[9px] tracking-wider text-accent transition hover:bg-accent/10 disabled:opacity-40"
                >
                  RESET
                </button>
              </div>
            </article>
          )
        })}
      </div>
    </HudFrame>
  )
}
