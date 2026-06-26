import { useCallback, useEffect, useRef, useState } from 'react'
import { api, type Fault, type Service, type TrafficState } from './api.ts'
import Scanlines from './components/Scanlines.tsx'
import ServiceRail from './components/ServiceRail.tsx'
import GrafanaStage from './components/GrafanaStage.tsx'
import FaultDeck, { type TimelineEntry } from './components/FaultDeck.tsx'
import TrafficControl from './components/TrafficControl.tsx'
import AgentConsole from './components/AgentConsole.tsx'

const MAX_TIMELINE = 60

export default function App() {
  const [services, setServices] = useState<Service[]>([])
  const [servicesLoading, setServicesLoading] = useState(true)
  const [traffic, setTraffic] = useState<TrafficState | null>(null)
  const [faults, setFaults] = useState<Fault[]>([])
  const [active, setActive] = useState<Set<string>>(new Set())
  const [timeline, setTimeline] = useState<TimelineEntry[]>([])
  const [clock, setClock] = useState(() => new Date())

  const log = useCallback((e: TimelineEntry) => {
    setTimeline((prev) => [...prev, e].slice(-MAX_TIMELINE))
  }, [])

  const refreshServices = useCallback(async () => {
    try {
      const { services } = await api.services()
      setServices(services)
    } catch {
      /* control plane down — leave last state */
    } finally {
      setServicesLoading(false)
    }
  }, [])

  const refreshTraffic = useCallback(async () => {
    try {
      setTraffic(await api.traffic())
    } catch {
      /* ignore */
    }
  }, [])

  // initial load
  useEffect(() => {
    api
      .faults()
      .then((r) => setFaults(r.faults))
      .catch(() => undefined)
    refreshServices()
    refreshTraffic()
  }, [refreshServices, refreshTraffic])

  // polling
  useEffect(() => {
    const a = setInterval(refreshServices, 4000)
    const b = setInterval(refreshTraffic, 5000)
    const c = setInterval(() => setClock(new Date()), 1000)
    return () => {
      clearInterval(a)
      clearInterval(b)
      clearInterval(c)
    }
  }, [refreshServices, refreshTraffic])

  // log service state transitions (down/degraded) so the feed narrates outages
  const prevStatus = useRef<Map<string, string>>(new Map())
  useEffect(() => {
    for (const s of services) {
      const before = prevStatus.current.get(s.id)
      if (before && before !== s.status && (s.status === 'down' || s.status === 'degraded')) {
        log({ at: Date.now(), kind: 'service', tone: 'danger', text: `${s.label} → ${s.status.toUpperCase()}` })
      }
      prevStatus.current.set(s.id, s.status)
    }
  }, [services, log])

  return (
    <div className="flex h-screen flex-col gap-2.5 p-2.5">
      <Scanlines />
      <TopBar clock={clock} traffic={traffic} activeCount={active.size} />

      <main className="grid min-h-0 flex-1 grid-cols-[clamp(240px,18vw,300px)_1fr_clamp(320px,26vw,440px)] gap-2.5">
        {/* LEFT — infrastructure rail */}
        <ServiceRail services={services} loading={servicesLoading} onChanged={refreshServices} />

        {/* CENTER — telemetry + fault injection */}
        <div className="grid min-h-0 grid-rows-[1fr_minmax(220px,38%)] gap-2.5">
          <GrafanaStage />
          <FaultDeck
            faults={faults}
            active={active}
            onActiveChange={setActive}
            onLog={log}
            onAfterAction={refreshServices}
          />
        </div>

        {/* RIGHT — agent + load */}
        <div className="grid min-h-0 grid-rows-[1fr_auto] gap-2.5">
          <AgentConsole timeline={timeline} />
          <TrafficControl traffic={traffic} onLog={log} onAfterAction={refreshTraffic} />
        </div>
      </main>
    </div>
  )
}

function TopBar({
  clock,
  traffic,
  activeCount,
}: {
  clock: Date
  traffic: TrafficState | null
  activeCount: number
}) {
  return (
    <header className="chamfer relative flex shrink-0 items-center justify-between border border-info/30 bg-panel/80 px-4 py-2 brackets">
      <div className="flex items-center gap-3">
        <span className="text-info text-glow">◆◇◆</span>
        <h1 className="title text-[15px] text-fg text-glow">
          Mission Control
          <span className="ml-2 text-info">// Cloud Incident Lab</span>
        </h1>
      </div>
      <div className="flex items-center gap-5 font-mono text-[11px]">
        <Indicator
          on={activeCount > 0}
          onText={`${activeCount} FAULT${activeCount > 1 ? 'S' : ''} ARMED`}
          offText="SYSTEMS NOMINAL"
          onTone="active"
        />
        <Indicator
          on={traffic?.running ?? false}
          onText={`TRAFFIC ▶ ${traffic?.alive ?? 0}`}
          offText="TRAFFIC IDLE"
          onTone="accent"
        />
        <span className="title text-info text-glow">
          {clock.toLocaleTimeString('en-GB', { hour12: false })}
        </span>
      </div>
    </header>
  )
}

function Indicator({
  on,
  onText,
  offText,
  onTone,
}: {
  on: boolean
  onText: string
  offText: string
  onTone: 'active' | 'accent'
}) {
  const cls = on ? (onTone === 'active' ? 'text-active glitch' : 'text-accent') : 'text-dim'
  return (
    <span className={`flex items-center gap-1.5 ${cls}`}>
      <span
        className={on ? 'pulse' : ''}
        style={{
          width: 7,
          height: 7,
          borderRadius: '50%',
          background: 'currentColor',
          boxShadow: on ? '0 0 8px currentColor' : 'none',
          display: 'inline-block',
        }}
      />
      {on ? onText : offText}
    </span>
  )
}
