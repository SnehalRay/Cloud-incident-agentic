import { useState } from 'react'
import { GRAFANA_URL } from '../api.ts'
import HudFrame from './HudFrame.tsx'

export default function GrafanaStage() {
  const [reloadKey, setReloadKey] = useState(0)
  const [failed, setFailed] = useState(false)

  return (
    <HudFrame
      title="Telemetry · Grafana"
      tone="info"
      className="scan-sweep"
      accessory={
        <div className="flex items-center gap-2">
          <span className="font-mono text-[10px] text-dim">live · 10s</span>
          <button
            onClick={() => {
              setFailed(false)
              setReloadKey((k) => k + 1)
            }}
            className="chamfer-sm border border-info/50 px-2 py-0.5 font-mono text-[9px] tracking-wider text-info hover:bg-info/10"
          >
            ↻ SYNC
          </button>
          <a
            href={GRAFANA_URL}
            target="_blank"
            rel="noreferrer"
            className="chamfer-sm border border-edge px-2 py-0.5 font-mono text-[9px] tracking-wider text-dim hover:text-fg"
          >
            ↗ OPEN
          </a>
        </div>
      }
      bodyClassName="relative bg-void"
    >
      <iframe
        key={reloadKey}
        src={GRAFANA_URL}
        title="Grafana dashboard"
        className="h-full w-full border-0"
        onError={() => setFailed(true)}
      />
      {failed && (
        <div className="absolute inset-0 flex items-center justify-center bg-void/90 p-6 text-center">
          <p className="font-mono text-[12px] text-danger">
            Grafana not reachable. Start the stack (make up) and ensure embedding is enabled.
          </p>
        </div>
      )}
    </HudFrame>
  )
}
