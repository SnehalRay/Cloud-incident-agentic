# Features

## Core Scope

### Infrastructure
- All services run in Kubernetes (kind for local dev)
- Kubernetes-native failure injection (OOM limits, eviction policies, crashloop triggers)

### Microservice System
- Frontend (React) with per-instance rate limit identity headers
- Backend API (Spring Boot) with Redis-backed sliding-window rate limiter
- Kafka event queue with consumer failure injection and DLQ
- PostgreSQL with sharding and hot-partition simulation
- Redis for cache and shared rate-limit state

### Observability Pipeline (Rust → Kafka → Prometheus → Grafana)
- Rust log pipeline reads structured JSON logs from all services
- Enriches and publishes log events to Kafka topic `log-events`
- Kafka consumer parses log events into Prometheus metrics
- Grafana dashboards: error rates, latency, queue depths, shard metrics, K8s events

### Incident Scenarios

#### 1. Rate Limit Storm
**Trigger:** Multiple frontend instances fire rapid POST requests
- Backend returns 429 Too Many Requests
- Violations pushed to Redis jobs queue
- Rust worker processes violations and writes to audit_log
- **Signal:** 429 rate in Grafana, jobs queue depth rising

#### 2. Kafka DLQ Overflow
**Trigger:** Kafka consumer injected with high failure rate
- Messages on `item-events` fail after N retries
- Failed messages routed to `item-events.DLQ`
- DLQ depth metric spikes
- **Signal:** Consumer lag, DLQ depth in Grafana

#### 3. Hot Database Shard
**Trigger:** Load-test script targets one shard exclusively
- Shard-1 CPU and latency diverge from shard-2
- Backend queries start timing out
- **Signal:** Per-shard latency/error metrics diverge

#### 4. Pod OOM Kill
**Trigger:** Memory-hungry load injected, K8s OOM limit hit
- Kubernetes kills the pod (OOMKilled exit code)
- Service restarts, brief unavailability
- **Signal:** OOMKilled in K8s pod events, restart count increase

#### 5. Pod Eviction (Node Pressure)
**Trigger:** Node memory/disk pressure threshold crossed
- K8s evicts lower-priority pods
- Service disruption across affected pods
- **Signal:** Eviction events in K8s, health check failures

#### 6. Backend Crash Loop
**Trigger:** Runtime exception injected into backend startup
- Pod enters CrashLoopBackOff
- Health checks fail continuously
- **Signal:** CrashLoopBackOff in pod status, restart count

#### 7. Redis Outage
**Trigger:** Redis pod killed
- Rate limiter falls back or fails open
- Cache misses spike, DB load increases
- **Signal:** Cache hit rate drop, DB CPU spike, rate limiter errors

---

## Agent Tools

- `get_service_health(service)` — K8s pod status, restart count, last heartbeat
- `get_logs(service, window)` — recent log lines from Rust pipeline / log store
- `get_metrics(service, window)` — latency, error rate, CPU, memory from Prometheus
- `get_recent_deployments(service)` — deploy history and config changes
- `search_runbooks(query)` — vector search over markdown runbooks
- `get_dependencies(service)` — service dependency map
- `get_incident_history(issue)` — similar past incidents
- `check_dlq_depth(topic)` — Kafka admin API: consumer lag and DLQ message count
- `get_k8s_events(service)` — pod events: OOMKilled, Evicted, CrashLoopBackOff
- `get_shard_metrics(shard)` — per-shard latency and error rates

---

## Agent Workflow (LangGraph)

- Intake node: understand question, classify incident type, identify target service
- Planning node: decide which tools to use and in what order
- Evidence collection node: run tools, gather logs/metrics/K8s events
- Synthesis node: combine evidence into ranked hypotheses
- Recommendation node: generate safe next steps

---

## Agent Output (structured)

- Incident summary
- Evidence list (logs, metrics, K8s events, DLQ depth, shard metrics)
- Likely root cause
- Confidence level
- Recommended next steps

---

## Dashboard

- Service status cards (healthy / degraded / unhealthy)
- K8s pod status panel (restart counts, evictions, OOM events)
- Kafka queue depth panel (consumer lag, DLQ depth)
- Ask-the-agent input
- Evidence panel
- Recommendation panel
- Incident history list

---

## Stretch Features

### Human Approval Flow
- Approval modal before any risky action executes (e.g. restart pod, scale deployment)
- Approval/rejection stored in DB

### Incident Postmortem Generator
- Timeline summary
- Root cause summary
- Action items
- Exportable report

### Agent Evaluation Dashboard
- Accuracy of diagnoses
- Tool call count per investigation
- Time to diagnosis
