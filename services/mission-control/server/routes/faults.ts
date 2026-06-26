import { Router } from 'express'
import path from 'node:path'
import { run, REPO_ROOT } from '../exec.ts'
import { FAULTS, FAULT_IDS } from '../catalog.ts'

export const faultsRouter = Router()

function scriptPath(id: string, script: 'trigger' | 'reset' | 'status'): string {
  return path.join(REPO_ROOT, 'faults', id, `${script}.sh`)
}

// GET /api/faults — the static fault catalog the deck renders.
faultsRouter.get('/', (_req, res) => {
  res.json({ faults: FAULTS })
})

// GET /api/faults/:id/status — run the fault's status.sh.
faultsRouter.get('/:id/status', async (req, res) => {
  const { id } = req.params
  if (!FAULT_IDS.has(id)) return res.status(404).json({ error: `unknown fault: ${id}` })
  const r = await run('bash', [scriptPath(id, 'status')], { timeoutMs: 30_000 })
  res.json({ ok: r.ok, output: (r.stdout + r.stderr).trim() })
})

// POST /api/faults/:id/:action  (action = trigger | reset)
faultsRouter.post('/:id/:action', async (req, res) => {
  const { id, action } = req.params
  if (!FAULT_IDS.has(id)) return res.status(404).json({ error: `unknown fault: ${id}` })
  if (action !== 'trigger' && action !== 'reset')
    return res.status(400).json({ error: `unknown action: ${action}` })

  // Fault bursts (rate-limit, crash-loop) can run for a while — give them room.
  const r = await run('bash', [scriptPath(id, action)], { timeoutMs: 180_000 })
  res.status(r.ok ? 200 : 500).json({
    ok: r.ok,
    id,
    action,
    output: (r.stdout + r.stderr).trim(),
  })
})
