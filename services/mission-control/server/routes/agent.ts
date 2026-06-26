import { Router } from 'express'
import { spawn } from 'node:child_process'
import { docker, REPO_ROOT } from '../exec.ts'

export const agentRouter = Router()

// GET /api/agent/status — is the agent's LLM backend (Ollama) up?
agentRouter.get('/status', async (_req, res) => {
  const r = await docker(['inspect', '--format', '{{.State.Running}}', 'incident-lab-ollama'], 15_000)
  res.json({ ready: r.ok && r.stdout.trim() === 'true' })
})

/**
 * GET /api/agent/stream — run one real diagnosis and stream it as SSE.
 *
 * Spawns `docker compose --profile agent run --rm agent` (the existing
 * LangGraph + Qwen agent) and forwards its stdout/stderr line-by-line so the
 * browser sees the live ReAct trace and the final timestamped root cause.
 */
agentRouter.get('/stream', (req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  })

  const send = (event: string, data: unknown) => {
    res.write(`event: ${event}\n`)
    res.write(`data: ${JSON.stringify(data)}\n\n`)
  }

  send('start', { at: Date.now() })

  const child = spawn('docker', ['compose', '--profile', 'agent', 'run', '--rm', 'agent'], {
    cwd: REPO_ROOT,
    env: process.env,
  })

  const pump = (channel: 'stdout' | 'stderr') => {
    let buf = ''
    return (chunk: Buffer) => {
      buf += chunk.toString()
      const lines = buf.split('\n')
      buf = lines.pop() ?? ''
      for (const line of lines) {
        if (line.trim() === '') continue
        send('line', { channel, text: line, at: Date.now() })
      }
    }
  }

  child.stdout.on('data', pump('stdout'))
  child.stderr.on('data', pump('stderr'))

  child.on('error', (err) => {
    send('agent_error', { message: `failed to launch agent: ${err.message}` })
    res.end()
  })

  child.on('close', (code) => {
    send('done', { code, at: Date.now() })
    res.end()
  })

  // If the browser navigates away / closes the panel, kill the run.
  req.on('close', () => {
    if (!child.killed) child.kill('SIGTERM')
  })
})
