import { execFile } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/**
 * Lab repo root. The control plane runs every script and docker command from
 * here. server/ lives at services/mission-control/server, so the repo root is
 * three levels up. Override with REPO_ROOT.
 */
export const REPO_ROOT =
  process.env.REPO_ROOT ?? path.resolve(__dirname, '..', '..', '..')

export interface RunResult {
  code: number
  stdout: string
  stderr: string
  ok: boolean
}

/**
 * Run a binary with a fixed argv array (never a shell string) so user-facing
 * ids can't be interpolated into a shell. Extra env is layered on top of the
 * process env. Output is captured and the call never rejects — callers inspect
 * `ok`/`code`.
 */
export function run(
  file: string,
  args: string[],
  opts: { env?: NodeJS.ProcessEnv; timeoutMs?: number; cwd?: string } = {},
): Promise<RunResult> {
  return new Promise((resolve) => {
    execFile(
      file,
      args,
      {
        cwd: opts.cwd ?? REPO_ROOT,
        env: { ...process.env, ...opts.env },
        timeout: opts.timeoutMs ?? 120_000,
        maxBuffer: 1024 * 1024 * 8,
      },
      (err, stdout, stderr) => {
        const code =
          err && typeof (err as { code?: number }).code === 'number'
            ? (err as { code: number }).code
            : err
              ? 1
              : 0
        resolve({
          code,
          stdout: stdout?.toString() ?? '',
          stderr: stderr?.toString() ?? '',
          ok: code === 0,
        })
      },
    )
  })
}

/** Convenience wrapper for `docker ...` calls. */
export function docker(args: string[], timeoutMs = 60_000): Promise<RunResult> {
  return run('docker', args, { timeoutMs })
}
