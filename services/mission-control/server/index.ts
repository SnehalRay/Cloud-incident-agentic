import express from 'express'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { servicesRouter } from './routes/services.ts'
import { faultsRouter } from './routes/faults.ts'
import { trafficRouter } from './routes/traffic.ts'
import { agentRouter } from './routes/agent.ts'
import { REPO_ROOT } from './exec.ts'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.CONTROL_PORT ?? 7070)
const HOST = '127.0.0.1' // executes shell/docker — never bind to a public iface

const app = express()
app.use(express.json())

// Permissive CORS — the server only listens on localhost anyway, and in dev the
// Vite proxy keeps the browser same-origin.
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') return res.sendStatus(204)
  next()
})

app.get('/api/health', (_req, res) => res.json({ ok: true, repoRoot: REPO_ROOT }))
app.use('/api/services', servicesRouter)
app.use('/api/faults', faultsRouter)
app.use('/api/traffic', trafficRouter)
app.use('/api/agent', agentRouter)

// In production, serve the built SPA. In dev, Vite serves the UI and proxies here.
if (process.env.NODE_ENV === 'production') {
  const dist = path.resolve(__dirname, '..', 'dist')
  app.use(express.static(dist))
  app.get(/^(?!\/api).*/, (_req, res) => res.sendFile(path.join(dist, 'index.html')))
}

app.listen(PORT, HOST, () => {
  console.log(`[mission-control] control plane on http://${HOST}:${PORT}`)
  console.log(`[mission-control] repo root: ${REPO_ROOT}`)
})
