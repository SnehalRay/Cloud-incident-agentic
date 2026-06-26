import { Router } from 'express'
import { spawn } from 'node:child_process'
import path from 'node:path'
import { run, REPO_ROOT } from '../exec.ts'

export const trafficRouter = Router()

const TRAFFIC_SH = path.join(REPO_ROOT, 'scripts', 'traffic.sh')

function parseStatus(raw: string): { running: boolean; alive: number; total: number; raw: string } {
  // Matches: "running: 18/20 workers alive ..."  or  "not running"
  const m = raw.match(/running:\s*(\d+)\/(\d+)/)
  if (!m) return { running: false, alive: 0, total: 0, raw: raw.trim() }
  const alive = Number(m[1])
  const total = Number(m[2])
  return { running: alive > 0, alive, total, raw: raw.trim() }
}

// GET /api/traffic — how many traffic workers are alive.
trafficRouter.get('/', async (_req, res) => {
  const r = await run('bash', [TRAFFIC_SH, 'status'], { timeoutMs: 15_000 })
  res.json(parseStatus(r.stdout + r.stderr))
})

// POST /api/traffic/start  body: { concurrency?, interval? }
trafficRouter.post('/start', (req, res) => {
  const concurrency = clampInt(req.body?.concurrency, 1, 500, 20)
  const interval = clampFloat(req.body?.interval, 0, 5, 0.05)

  // Detach: the script forks long-lived workers. If we captured stdout they'd
  // hold the pipe open and the request would hang. stdio:'ignore' + unref lets
  // the workers keep running after we return; GET /api/traffic confirms state.
  const child = spawn('bash', [TRAFFIC_SH, 'start'], {
    cwd: REPO_ROOT,
    env: { ...process.env, CONCURRENCY: String(concurrency), INTERVAL: String(interval) },
    detached: true,
    stdio: 'ignore',
  })
  child.unref()
  res.json({ ok: true, concurrency, interval })
})

// POST /api/traffic/stop
trafficRouter.post('/stop', async (_req, res) => {
  const r = await run('bash', [TRAFFIC_SH, 'stop'], { timeoutMs: 20_000 })
  res.json({ ok: r.ok, output: (r.stdout + r.stderr).trim() })
})

function clampInt(v: unknown, min: number, max: number, fallback: number): number {
  const n = Math.round(Number(v))
  if (!Number.isFinite(n)) return fallback
  return Math.min(max, Math.max(min, n))
}

function clampFloat(v: unknown, min: number, max: number, fallback: number): number {
  const n = Number(v)
  if (!Number.isFinite(n)) return fallback
  return Math.min(max, Math.max(min, n))
}
