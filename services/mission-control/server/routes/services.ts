import { Router } from 'express'
import { docker } from '../exec.ts'
import { SERVICES, serviceById } from '../catalog.ts'

export const servicesRouter = Router()

export type ServiceStatus = 'up' | 'degraded' | 'starting' | 'down' | 'absent'

async function statusOf(container: string): Promise<{ status: ServiceStatus; health: string }> {
  const r = await docker(
    [
      'inspect',
      '--format',
      '{{.State.Running}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}',
      container,
    ],
    15_000,
  )
  if (!r.ok) return { status: 'absent', health: 'none' }
  const [running, health = 'none'] = r.stdout.trim().split('|')
  if (running !== 'true') return { status: 'down', health }
  if (health === 'unhealthy') return { status: 'degraded', health }
  if (health === 'starting') return { status: 'starting', health }
  return { status: 'up', health }
}

// GET /api/services — live status of every catalog service.
servicesRouter.get('/', async (_req, res) => {
  const items = await Promise.all(
    SERVICES.map(async (s) => ({
      id: s.id,
      label: s.label,
      kind: s.kind,
      role: s.role,
      controllable: s.controllable,
      ...(await statusOf(s.container)),
    })),
  )
  res.json({ services: items })
})

// POST /api/services/:id/:action  (action = start | stop | restart)
servicesRouter.post('/:id/:action', async (req, res) => {
  const { id, action } = req.params
  const svc = serviceById(id)
  if (!svc) return res.status(404).json({ error: `unknown service: ${id}` })
  if (!svc.controllable) return res.status(400).json({ error: `${id} is not controllable` })
  if (!['start', 'stop', 'restart'].includes(action))
    return res.status(400).json({ error: `unknown action: ${action}` })

  const r = await docker([action, svc.container], 60_000)
  res.status(r.ok ? 200 : 500).json({
    ok: r.ok,
    action,
    id,
    output: (r.stdout || r.stderr).trim(),
  })
})
