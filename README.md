# Cloud-incident-lab

<img width="1236" height="775" alt="Screenshot 2026-06-26 at 14 41 47" src="https://github.com/user-attachments/assets/aa540dd4-defd-4b54-8aac-ff1a4828d2d7" />


## Setup

```bash
cp .env.example .env
```

## Commands

| Command | Description |
|---|---|
| `make up` | Start all services |
| `make down` | Stop containers (keeps data and images) |
| `make reset` | Wipe data, rebuild, and restart fresh |
| `make nuke` | Full clean slate — removes containers, data, and images, then restarts |
| `make destroy` | Delete everything and stop — no restart |
| `make ps` | Show container status and health |
| `make logs` | Tail logs for all services |
| `make ping-redis` | Smoke test Redis (should return PONG) |
| `make psql` | Open a psql shell inside the Postgres container |

### Local development

| Command | Description |
|---|---|
| `make start-infra` | Start only Postgres + Redis (for local Spring dev) |
| `make start-spring` | Run Spring Boot locally against Docker infra |
| `make start-frontend` | Run the React dev server at `http://localhost:5173` |

## Ports

| Service | Host port |
|---|---|
| Postgres | `5433` (5432 is reserved for local install) |
| Redis | `6379` |
| Backend | `8080` |
| Frontend (Docker) | `3000` |
| Frontend (dev server) | `5173` |

## Frontend

The React app has two pages:

- **Items** — fetches and displays all items from `GET /api/items`
- **Status** — shows backend health and dependency status (Postgres, Redis) from `GET /api/status`

To run the frontend locally against the backend:

```bash
make start-spring      # terminal 1 — starts infra + Spring Boot
make start-frontend    # terminal 2 — starts Vite dev server
```

Then open `http://localhost:5173`.

To stop just Postgres and Redis without affecting other containers:

```bash
docker compose stop postgres redis
```

To bring them back:

```bash
docker compose start postgres redis
```
