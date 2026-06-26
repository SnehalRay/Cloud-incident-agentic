import { useEffect, useMemo, useRef, useState } from 'react'
import { api } from '../api.ts'
import HudFrame from './HudFrame.tsx'
import type { TimelineEntry } from './FaultDeck.tsx'

type LineType = 'tool' | 'ai' | 'stderr' | 'system'
interface AgentLine {
  at: number
  type: LineType
  text: string
}

type FeedRow =
  | { src: 'agent'; at: number; type: LineType; text: string }
  | { src: 'ops'; at: number; entry: TimelineEntry }

type RunState = 'idle' | 'running' | 'done' | 'error'

const toneClass: Record<TimelineEntry['tone'], string> = {
  accent: 'text-accent',
  info: 'text-info',
  active: 'text-active',
  danger: 'text-danger',
}

function ts(at: number): string {
  return new Date(at).toLocaleTimeString('en-GB', { hour12: false })
}

export default function AgentConsole({ timeline }: { timeline: TimelineEntry[] }) {
  const [lines, setLines] = useState<AgentLine[]>([])
  const [state, setState] = useState<RunState>('idle')
  const [ready, setReady] = useState<boolean | null>(null)
  const esRef = useRef<EventSource | null>(null)
  const scrollRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    api
      .agentStatus()
      .then((r) => setReady(r.ready))
      .catch(() => setReady(false))
    return () => esRef.current?.close()
  }, [])

  const feed = useMemo<FeedRow[]>(() => {
    const rows: FeedRow[] = [
      ...lines.map((l) => ({ src: 'agent' as const, at: l.at, type: l.type, text: l.text })),
      ...timeline.map((e) => ({ src: 'ops' as const, at: e.at, entry: e })),
    ]
    return rows.sort((a, b) => a.at - b.at)
  }, [lines, timeline])

  useEffect(() => {
    const el = scrollRef.current
    if (el) el.scrollTop = el.scrollHeight
  }, [feed.length])

  function push(type: LineType, text: string, at = Date.now()) {
    setLines((prev) => [...prev, { at, type, text }])
  }

  function run() {
    if (state === 'running') return
    setLines([])
    setState('running')
    push('system', '◆ DIAGNOSIS INITIATED — querying Prometheus…')

    const es = new EventSource('/api/agent/stream')
    esRef.current = es

    es.addEventListener('line', (ev) => {
      const d = JSON.parse((ev as MessageEvent).data) as {
        channel: string
        text: string
        at: number
      }
      const trimmed = d.text.trim()
      if (d.channel === 'stderr') push('stderr', d.text, d.at)
      else if (trimmed.startsWith('->')) push('tool', trimmed.replace(/^->\s*/, ''), d.at)
      else push('ai', d.text, d.at)
    })

    es.addEventListener('agent_error', (ev) => {
      const d = JSON.parse((ev as MessageEvent).data) as { message: string }
      push('stderr', d.message)
      setState('error')
      es.close()
    })

    es.addEventListener('done', (ev) => {
      const d = JSON.parse((ev as MessageEvent).data) as { code: number }
      push('system', d.code === 0 ? '◆ DIAGNOSIS COMPLETE' : `◆ AGENT EXITED (code ${d.code})`)
      setState(d.code === 0 ? 'done' : 'error')
      es.close()
    })

    // native connection error (server unreachable / stream dropped before done)
    es.onerror = () => {
      if (esRef.current && state !== 'done') {
        push('stderr', 'stream interrupted — is the control plane running?')
      }
      setState((s) => (s === 'running' ? 'error' : s))
      es.close()
    }
  }

  return (
    <HudFrame
      title="AI Diagnosis Agent"
      tone="accent"
      accessory={
        <div className="flex items-center gap-2">
          <span
            className={`font-mono text-[9px] ${
              ready === null ? 'text-dim' : ready ? 'text-accent' : 'text-warn'
            }`}
          >
            {ready === null ? 'CHECK…' : ready ? 'LLM ONLINE' : 'LLM OFFLINE'}
          </span>
          <button
            onClick={run}
            disabled={state === 'running'}
            className="chamfer-sm border border-accent/60 px-2 py-0.5 font-mono text-[9px] tracking-wider text-accent transition hover:bg-accent/10 disabled:opacity-40"
          >
            {state === 'running' ? 'RUNNING…' : '▶ DIAGNOSE'}
          </button>
        </div>
      }
      bodyClassName="relative flex min-h-0 flex-col"
    >
      <div
        ref={scrollRef}
        className="min-h-0 flex-1 overflow-y-auto bg-void/60 p-3 font-mono text-[11px] leading-relaxed"
      >
        {feed.length === 0 && (
          <div className="text-dim">
            <p>{'>'} mission-control diagnosis terminal</p>
            <p className="mt-1 opacity-70">
              inject a fault, then hit DIAGNOSE. the agent reads live Prometheus metrics, isolates
              the single root cause, and reports it here — timestamped.
            </p>
            {ready === false && (
              <p className="mt-2 text-warn">
                ⚠ LLM offline. Start it once: <span className="text-fg">make agent-up</span>
              </p>
            )}
          </div>
        )}

        {feed.map((row, i) =>
          row.src === 'ops' ? (
            <div key={i} className="flex gap-2 py-0.5">
              <span className="shrink-0 text-dim">{ts(row.at)}</span>
              <span className="shrink-0 text-dim">│</span>
              <span className={`${toneClass[row.entry.tone]} text-glow`}>
                ▣ {row.entry.text}
              </span>
            </div>
          ) : (
            <div key={i} className="flex gap-2 py-0.5">
              <span className="shrink-0 text-dim">{ts(row.at)}</span>
              <span className="shrink-0 text-dim">│</span>
              <AgentText type={row.type} text={row.text} />
            </div>
          ),
        )}
        {state === 'running' && <span className="caret text-accent" />}
      </div>
    </HudFrame>
  )
}

function AgentText({ type, text }: { type: LineType; text: string }) {
  if (type === 'tool')
    return (
      <span className="text-info">
        <span className="text-info/60">↳ tool</span> {text}
      </span>
    )
  if (type === 'stderr') return <span className="text-danger/80">{text}</span>
  if (type === 'system') return <span className="text-active text-glow">{text}</span>
  return <span className="whitespace-pre-wrap text-fg">{text}</span>
}
