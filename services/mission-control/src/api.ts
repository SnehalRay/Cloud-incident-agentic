// Typed client for the control-plane API. In dev these are relative paths that
// Vite proxies to the Express server on :7070.

export type ServiceStatus = 'up' | 'degraded' | 'starting' | 'down' | 'absent'
export type ServiceKind = 'app' | 'data' | 'queue' | 'observability' | 'agent'

export interface Service {
  id: string
  label: string
  kind: ServiceKind
  role: string
  controllable: boolean
  status: ServiceStatus
  health: string
}

export interface Fault {
  id: string
  label: string
  target: string
  blurb: string
  watch: string
  defaults: string
}

export interface TrafficState {
  running: boolean
  alive: number
  total: number
  raw: string
}

export interface ActionResult {
  ok: boolean
  output?: string
  [k: string]: unknown
}

async function json<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, init)
  if (!res.ok && res.status >= 500) {
    // surface server errors but still try to parse a body
    try {
      return (await res.json()) as T
    } catch {
      throw new Error(`${res.status} ${res.statusText}`)
    }
  }
  return (await res.json()) as T
}

function post(path: string, body?: unknown): Promise<ActionResult> {
  return json<ActionResult>(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  })
}

export const api = {
  health: () => json<{ ok: boolean; repoRoot: string }>('/api/health'),

  services: () => json<{ services: Service[] }>('/api/services'),
  serviceAction: (id: string, action: 'start' | 'stop' | 'restart') =>
    post(`/api/services/${id}/${action}`),

  faults: () => json<{ faults: Fault[] }>('/api/faults'),
  faultStatus: (id: string) => json<ActionResult>(`/api/faults/${id}/status`),
  faultAction: (id: string, action: 'trigger' | 'reset') => post(`/api/faults/${id}/${action}`),

  traffic: () => json<TrafficState>('/api/traffic'),
  trafficStart: (concurrency: number, interval: number) =>
    post('/api/traffic/start', { concurrency, interval }),
  trafficStop: () => post('/api/traffic/stop'),

  agentStatus: () => json<{ ready: boolean }>('/api/agent/status'),
}

export const GRAFANA_URL =
  (import.meta.env.VITE_GRAFANA_URL as string | undefined) ??
  'http://localhost:3001/d/incident-lab-main/cloud-incident-lab?orgId=1&kiosk&theme=dark&refresh=10s'
