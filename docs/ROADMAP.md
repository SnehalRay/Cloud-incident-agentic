# Roadmap

## Primary Objective

Build a local cloud-simulated incident-response platform where an AI agent can diagnose production-style distributed systems failures using logs, metrics, K8s events, and runbooks — and explain its reasoning with evidence.

### What makes this different from a basic project
- Failures are distributed systems failures, not just "service X is down"
- Observability is a Rust pipeline, not just log tailing
- Infrastructure is Kubernetes, not just Docker Compose
- Agent has K8s-aware tools (pod events, evictions, DLQ depth, shard metrics)

---

## Phase Overview

| Phase | Focus                              | Output                                              |
|-------|------------------------------------|-----------------------------------------------------|
| 1     | Core services + rate limiter       | Working app with rate limiting ✓ (done)             |
| 2     | Kafka + DLQ                        | Event queue with consumer failures and DLQ          |
| 3     | PostgreSQL sharding + hot partition | Sharded DB with hot-partition failure scenario      |
| 4     | Kubernetes migration               | All services running in K8s (kind)                  |
| 5     | K8s fault scenarios                | OOM kill, eviction, crashloop triggerable           |
| 6     | Rust log pipeline                  | Logs → Kafka → Prometheus metrics flowing           |
| 7     | Grafana dashboards                 | All failure signals visible in dashboards           |
| 8     | Agent tools + workflow             | Agent diagnoses all 7 scenarios correctly           |
| 9     | Dashboard + polish                 | Fully demoable, portfolio-ready                     |

---

## Phase 1 — Core Services + Rate Limiter ✓ DONE

Backend (Spring Boot), Frontend (React), PostgreSQL, Redis, Rust worker.
Rate limiter: Redis sliding-window per instance ID, 429 on violation, violation pushed to jobs queue.

---

## Phase 2 — Kafka + DLQ

**Goal:** Add an event-driven pipeline with realistic consumer failure injection.

- [ ] Add Kafka + Zookeeper to Docker Compose (or K8s later)
- [ ] Backend publishes to `item-events` topic on POST /api/items
- [ ] Python consumer service processes `item-events`
- [ ] Consumer has configurable failure rate (env var: `FAILURE_RATE=0.3`)
- [ ] Failed messages retry N times then go to `item-events.DLQ`
- [ ] DLQ depth exposed as a Prometheus metric
- [ ] Incident scenario: set FAILURE_RATE=0.9, watch DLQ fill

**Milestone:** DLQ depth spikes in Prometheus when consumer failure rate is high.

---

## Phase 3 — PostgreSQL Sharding + Hot Partition

**Goal:** Add a shard-imbalance failure scenario.

- [ ] Set up 2 PostgreSQL instances: shard-1, shard-2
- [ ] Backend routes writes based on item ID hash (even → shard-1, odd → shard-2)
- [ ] Each shard exposes per-shard metrics (latency, connection count, CPU)
- [ ] Load-test script that targets only shard-1 keys
- [ ] Incident scenario: run hot-partition script, watch shard-1 metrics diverge
- [ ] Backend returns 500s when shard-1 is overwhelmed

**Milestone:** Per-shard metrics show divergence during hot-partition scenario.

---

## Phase 4 — Kubernetes Migration

**Goal:** Move all services from Docker Compose to Kubernetes (kind).

- [ ] Install kind, set up local cluster
- [ ] Write K8s manifests for all services (Deployments, Services, ConfigMaps, Secrets)
- [ ] Set memory limits on backend pod (needed for OOM scenario)
- [ ] Set up PodDisruptionBudgets and priority classes for eviction scenario
- [ ] Verify all services healthy in K8s: `kubectl get pods`
- [ ] Keep Docker Compose for fast local iteration (K8s is primary)

**Milestone:** `kubectl get pods` shows all services Running.

---

## Phase 5 — Kubernetes Fault Scenarios

**Goal:** K8s-native failures that can be triggered on demand.

- [ ] OOM kill scenario: inject memory pressure until pod hits limit → OOMKilled
- [ ] Eviction scenario: fill node disk/memory to trigger K8s eviction
- [ ] CrashLoop scenario: inject startup exception into backend → CrashLoopBackOff
- [ ] Each scenario has a trigger script in `incident-scenarios/`
- [ ] Each scenario has a reset script
- [ ] K8s events visible in observability pipeline

**Milestone:** All 3 K8s fault scenarios triggerable and resettable on demand.

---

## Phase 6 — Rust Log Pipeline

**Goal:** Replace ad-hoc log tailing with a structured Rust pipeline that feeds metrics.

- [ ] All services emit structured JSON logs (already done for backend)
- [ ] Rust pipeline reads log output from each service (file tail or K8s log API)
- [ ] Pipeline parses log events: severity, service, endpoint, duration, status code
- [ ] Pipeline publishes to Kafka topic `log-events`
- [ ] Kafka consumer reads `log-events` and increments Prometheus counters/histograms
- [ ] Metrics: error_rate_total, request_latency_seconds, dlq_depth, shard_error_total

**Milestone:** Prometheus shows metrics derived from log events in real time.

---

## Phase 7 — Grafana Dashboards

**Goal:** Every failure scenario has a visible signal in Grafana before agent work begins.

- [ ] Per-service dashboard: request rate, error rate, latency p50/p95/p99
- [ ] Rate limiter panel: 429 rate per instance
- [ ] Kafka panel: consumer lag, DLQ depth per topic
- [ ] Database panel: per-shard latency, connection count, error rate
- [ ] K8s panel: pod restart count, OOMKilled events, eviction events
- [ ] All panels populated from Prometheus (fed by Rust log pipeline)

**Milestone:** Triggering any incident scenario shows a visible signal in Grafana within 30 seconds.

---

## Phase 8 — Agent Tools + Workflow

**Goal:** Agent can diagnose all 7 failure scenarios.

- [ ] Core tools: `get_service_health`, `get_logs`, `get_metrics`, `get_recent_deployments`, `search_runbooks`
- [ ] New tools: `check_dlq_depth`, `get_k8s_events`, `get_shard_metrics`
- [ ] LangGraph workflow: intake → plan → evidence → synthesis → recommendation
- [ ] Agent tested against all 7 scenarios
- [ ] Structured JSON diagnosis for each

**Milestone:** Agent correctly identifies root cause for 6/7 scenarios.

---

## Phase 9 — Dashboard + Polish

**Goal:** Fully demoable, portfolio-ready.

- [ ] React dashboard: service status, K8s pod panel, Kafka panel, ask-agent, evidence, recommendations
- [ ] Approval modal for risky actions
- [ ] Postmortem generation
- [ ] Architecture diagram
- [ ] Demo script (one incident end-to-end)
- [ ] Demo video (2 minutes)

**Milestone:** End-to-end live demo works cleanly from browser open to postmortem displayed.

---

## MVP Definition

> A user can open the dashboard, trigger a distributed systems failure, ask the agent why it's failing, and receive a structured diagnosis with evidence and recommended next steps.

That means:
- All 7 incident scenarios triggerable
- Rust log pipeline flowing into Prometheus/Grafana
- 8 agent tools working
- Agent produces: summary + evidence + root cause + confidence + recommendations
- Dashboard shows the diagnosis

---

## What Was Explicitly Removed from Old Scope

| Old item              | Status         | Reason                            |
|-----------------------|----------------|-----------------------------------|
| Loki log aggregation  | Removed        | Replaced by Rust pipeline + Kafka |
| "No Kubernetes yet"   | Reversed       | K8s is now core to the scope      |
| Docker Compose only   | Replaced       | K8s (kind) is primary runtime     |
| Simple worker backlog | Replaced       | Kafka DLQ is richer scenario      |
