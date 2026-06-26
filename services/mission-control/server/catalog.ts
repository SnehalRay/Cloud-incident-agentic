/**
 * Static metadata describing the lab's runtime. This is the single source of
 * truth the control plane uses to decide what it's allowed to act on — every
 * fault id and service id coming from the browser is validated against these
 * lists before any docker/script call runs.
 */

export type ServiceKind = 'app' | 'data' | 'queue' | 'observability' | 'agent'

export interface ServiceDef {
  /** Stable id used in the API and UI. */
  id: string
  /** Display name. */
  label: string
  /** Docker container name to inspect / start / stop. */
  container: string
  kind: ServiceKind
  /** Short description of the role this service plays. */
  role: string
  /** Whether the rail offers start/stop controls (false for ephemeral/agent). */
  controllable: boolean
}

export interface FaultDef {
  /** Directory name under faults/ — also the API id. */
  id: string
  label: string
  /** Service id this fault primarily hits (links a fault to the rail). */
  target: string
  /** One-line description of what the fault does. */
  blurb: string
  /** The Grafana signal an operator should watch. */
  watch: string
  /** Default knobs shown read-only in the UI (informational). */
  defaults: string
}

/** Core runtime services, ordered for the left rail. */
export const SERVICES: ServiceDef[] = [
  { id: 'backend', label: 'Backend API', container: 'incident-lab-backend', kind: 'app', role: 'Spring Boot · /api/items', controllable: true },
  { id: 'worker', label: 'Worker', container: 'incident-lab-worker', kind: 'app', role: 'Rust · drains jobs:queue', controllable: true },
  { id: 'log-pipeline', label: 'Log Pipeline', container: 'incident-lab-log-pipeline', kind: 'observability', role: 'Rust · derives metrics :9091', controllable: true },
  { id: 'redis', label: 'Redis', container: 'incident-lab-redis', kind: 'data', role: 'Cache + rate-limit state', controllable: true },
  { id: 'postgres-shard-1', label: 'Postgres · Shard 1', container: 'incident-lab-postgres-shard-1', kind: 'data', role: 'Even-hash items', controllable: true },
  { id: 'postgres-shard-2', label: 'Postgres · Shard 2', container: 'incident-lab-postgres-shard-2', kind: 'data', role: 'Odd-hash items', controllable: true },
  { id: 'kafka', label: 'Kafka', container: 'incident-lab-kafka', kind: 'queue', role: 'KRaft broker · item-events', controllable: true },
  { id: 'kafka-consumer', label: 'Kafka Consumer', container: 'incident-lab-kafka-consumer', kind: 'queue', role: 'Rust · drains topic → DLQ', controllable: true },
  { id: 'kafka-exporter', label: 'Kafka Exporter', container: 'incident-lab-kafka-exporter', kind: 'observability', role: 'Lag + offsets → Prometheus', controllable: true },
  { id: 'prometheus', label: 'Prometheus', container: 'incident-lab-prometheus', kind: 'observability', role: 'Scrapes :9091 every 10s', controllable: true },
  { id: 'grafana', label: 'Grafana', container: 'incident-lab-grafana', kind: 'observability', role: 'Dashboards over Prometheus', controllable: true },
  { id: 'frontend', label: 'Workload Frontend', container: 'incident-lab-frontend', kind: 'app', role: 'React app under test', controllable: true },
  { id: 'ollama', label: 'Ollama (agent LLM)', container: 'incident-lab-ollama', kind: 'agent', role: 'Local model server', controllable: false },
]

/** Fault scenarios — id MUST match a directory under faults/. */
export const FAULTS: FaultDef[] = [
  { id: 'slow-request-fault', label: 'Slow Requests', target: 'backend', blurb: 'Flood the backend with slow calls → thread-pool exhaustion.', watch: 'P95 duration · slow req/s', defaults: 'WORKERS=20 DELAY=10000' },
  { id: 'crash-loop-fault', label: 'Crash Loop', target: 'backend', blurb: 'Repeatedly crash the JVM so Docker restarts it in a loop.', watch: 'Container restarts', defaults: 'CRASHES=3 GAP=4' },
  { id: 'rate-limit-fault', label: 'Rate-Limit Storm', target: 'backend', blurb: 'Burst POSTs past the per-instance limit → 429 violations.', watch: 'Rate-limit violations/s', defaults: 'REQUESTS=10 ×3 instances' },
  { id: 'redis-outage-fault', label: 'Redis Outage', target: 'redis', blurb: 'Stop Redis → rate-limiter fails open, cache-miss flood.', watch: 'Redis unavailable/s · cache errors', defaults: 'no args' },
  { id: 'hot-shard-fault', label: 'Hot Shard', target: 'postgres-shard-1', blurb: 'Saturate shard-1 connection pool with slow queries.', watch: 'Shard overload · DB slow queries', defaults: 'CONNECTIONS=15 DURATION=10000' },
  { id: 'network-degradation-fault', label: 'Network Degradation', target: 'postgres-shard-1', blurb: 'tc-netem latency/jitter/loss on a shard — slow, not severed.', watch: 'DB slow queries · P95', defaults: '200ms ±50ms · 1% loss' },
  { id: 'network-partition-fault', label: 'Network Partition', target: 'postgres-shard-2', blurb: 'Sever shard-2 from the network → ~50% of writes hang.', watch: 'DB write failures (shard-2)', defaults: 'SHARD=1' },
  { id: 'oom-kill-fault', label: 'OOM Kill', target: 'backend', blurb: 'Run a memory-capped container until the kernel OOM-kills it.', watch: 'OOM kills', defaults: '64m cap · 10MB chunks' },
  { id: 'dlq-fault', label: 'DLQ Overflow', target: 'kafka-consumer', blurb: 'Restart consumer at 90% fail-rate → messages flood the DLQ.', watch: 'Consumer lag · DLT offset', defaults: 'fail_rate=0.9' },
]

export const SERVICE_IDS = new Set(SERVICES.map((s) => s.id))
export const FAULT_IDS = new Set(FAULTS.map((f) => f.id))

export function serviceById(id: string): ServiceDef | undefined {
  return SERVICES.find((s) => s.id === id)
}
