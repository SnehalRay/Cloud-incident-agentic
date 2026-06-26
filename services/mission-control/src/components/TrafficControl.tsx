import { useState } from 'react'
import { api, type TrafficState } from '../api.ts'
import HudFrame from './HudFrame.tsx'
import type { TimelineEntry } from './FaultDeck.tsx'

interface Props {
  traffic: TrafficState | null
  onLog: (e: TimelineEntry) => void
  onAfterAction: () => void
}

export default function TrafficControl({ traffic, onLog, onAfterAction }: Props) {
  const [concurrency, setConcurrency] = useState(20)
  const [busy, setBusy] = useState(false)
  const running = traffic?.running ?? false

  async function start() {
    setBusy(true)
    try {
      await api.trafficStart(concurrency, 0.05)
      onLog({ at: Date.now(), kind: 'traffic', tone: 'info', text: `TRAFFIC ON · ${concurrency} workers` })
      setTimeout(onAfterAction, 800)
    } finally {
      setBusy(false)
    }
  }

  async function stop() {
    setBusy(true)
    try {
      await api.trafficStop()
      onLog({ at: Date.now(), kind: 'traffic', tone: 'accent', text: 'TRAFFIC OFF' })
      setTimeout(onAfterAction, 600)
    } finally {
      setBusy(false)
    }
  }

  return (
    <HudFrame
      title="Load Generator"
      tone="info"
      accessory={
        <span className="font-mono text-[10px]">
          {running ? (
            <span className="text-accent text-glow">
              ▶ {traffic?.alive ?? 0}/{traffic?.total ?? 0}
            </span>
          ) : (
            <span className="text-dim">■ IDLE</span>
          )}
        </span>
      }
      bodyClassName="p-3"
    >
      <div className="flex flex-col gap-3">
        <label className="flex items-center justify-between gap-3 font-mono text-[10px] text-dim">
          <span>
            CONCURRENCY <span className="text-info">{concurrency}</span>
          </span>
          <input
            type="range"
            min={1}
            max={100}
            value={concurrency}
            disabled={running}
            onChange={(e) => setConcurrency(Number(e.target.value))}
            className="h-1 w-32 cursor-pointer appearance-none rounded bg-muted accent-info disabled:opacity-40"
          />
        </label>
        <div className="flex gap-2">
          <button
            disabled={busy || running}
            onClick={start}
            className="chamfer-sm flex-1 border border-accent/60 py-2 font-mono text-[11px] tracking-wider text-accent transition hover:bg-accent/10 disabled:opacity-40"
          >
            {busy && !running ? '···' : '▶ START'}
          </button>
          <button
            disabled={busy || !running}
            onClick={stop}
            className="chamfer-sm flex-1 border border-danger/60 py-2 font-mono text-[11px] tracking-wider text-danger transition hover:bg-danger/10 disabled:opacity-40"
          >
            {busy && running ? '···' : '■ STOP'}
          </button>
        </div>
        <p className="font-mono text-[9px] leading-snug text-dim">
          Sustained read/write load against the backend — what makes faults show up as steady
          signals the agent can reason about.
        </p>
      </div>
    </HudFrame>
  )
}
