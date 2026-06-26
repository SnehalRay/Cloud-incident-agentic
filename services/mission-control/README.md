# Mission Control

A cyborg-styled control panel for the Cloud Incident Lab. One screen to run the
whole lab: watch the fleet, drive load, inject faults, see live Grafana, and let
the AI agent diagnose what broke — and when.

```
┌──────────┬───────────────────────────────┬─────────────────┐
│ SERVICE  │       GRAFANA STAGE           │   AI AGENT       │
│  RAIL    │   (embedded live dashboard)   │   CONSOLE        │
│ start/   ├───────────────────────────────┤  (streamed       │
│ stop     │       FAULT INJECTION         │   diagnosis +    │
│ + status │   inject / reset · 9 faults   │   ops timeline)  │
│          │                               ├─────────────────┤
│          │                               │  LOAD GENERATOR  │
└──────────┴───────────────────────────────┴─────────────────┘
```

## Architecture

This is a **separate, isolated app** — it does not touch the workload frontend in
`services/frontend-app`. It has two halves living in one project:

- **`src/`** — Vite + React 19 + Tailwind v4 cyberpunk UI.
- **`server/`** — a tiny Express **control plane** (localhost-only) that shells
  out to the lab's *existing* assets. It reimplements nothing:
  - services rail → `docker inspect` / `docker start|stop`
  - faults → `bash faults/<id>/{trigger,reset,status}.sh`
  - load → `bash scripts/traffic.sh start|stop|status`
  - agent → streams `docker compose --profile agent run --rm agent` over SSE

Because a browser can't run docker/scripts, the control plane is what makes the
buttons real. It binds to `127.0.0.1` only.

## Run

From the repo root:

```bash
make up               # start the lab (so there's something to control)
make mission-control  # installs deps on first run, then serves the UI
```

Open **http://localhost:5174**.

For the AI agent panel, pull the model once: `make agent-up` (~9GB, Ollama).

## Ports

| Piece                  | Port |
|------------------------|------|
| Mission Control UI     | 5174 |
| Control-plane API      | 7070 |
| Grafana (embedded)     | 3001 |

## Config

Copy `.env.example` → `.env` to override `CONTROL_PORT`, `GRAFANA_URL`, or
`REPO_ROOT`. The Grafana embed requires the `grafana` service in
`docker-compose.yml` to allow embedding (already wired:
`GF_AUTH_ANONYMOUS_ENABLED`, `GF_SECURITY_ALLOW_EMBEDDING`).

## Scripts

- `npm run dev` — control plane + Vite together (what `make mission-control` runs)
- `npm run build` — typecheck + production bundle
- `npm start` — serve the built bundle from the control plane (`NODE_ENV=production`)
