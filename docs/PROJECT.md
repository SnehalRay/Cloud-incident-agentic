# Cloud Incident Lab + Agentic Ops Copilot

## What Is This?

A local cloud-simulated incident-response platform paired with an AI-powered SRE copilot.

The project is split into two worlds:

**World 1 — The system being monitored**
A microservices app running on Kubernetes that fails in realistic distributed-systems ways: rate limit storms, Kafka DLQ overflow, hot database shards, and Kubernetes-native faults (OOM kills, pod evictions, node pressure).

**World 2 — The agent system**
An AI assistant that investigates those failures the same way a real SRE would.

Instead of a generic chatbot, the agent uses tools to:
- Inspect logs
- Inspect metrics
- Check service health
- Review deployment history
- Search runbooks
- Form hypotheses and rank root causes
- Recommend safe remediation steps

---

## The Real-World Story

Imagine a production system with a frontend, backend API, sharded database, cache, and an event-driven processing pipeline.

Something goes wrong:
- Rate limiters start rejecting requests in bursts
- A Kafka consumer starts failing — messages pile up and overflow into the DLQ
- One database shard is getting 80% of the writes — hot partition
- A pod gets OOM-killed by Kubernetes under memory pressure
- A node goes into pressure and starts evicting pods

Normally an SRE investigates by checking logs, metrics, health checks, recent deploys, and runbooks.

This project simulates that entire process — and your AI agent acts like a junior SRE assistant doing the investigation.

**One-line pitch:**
> "I built an AI-powered incident investigation platform for a Kubernetes-based microservices system with realistic distributed systems faults."

---

## Architecture

```
         Frontend (React)
               |
     [X-Instance-ID header]
               |
               v
         Backend API (Spring Boot)
          |         |         |
          |         v         |
          |    Rate Limiter   |
          |    (Redis)        |
          |    429 → jobs:q   |
          v                   v
     PostgreSQL            Kafka
     (sharded)          (item-events)
      shard-1 ← HOT       |
      shard-2           Consumer
                        Service
                          |
                    failures → DLQ
                    (item-events.DLQ)

OBSERVABILITY PIPELINE:
All Services → Structured JSON Logs
                        |
                        v
               Rust Log Pipeline
                        |
                        v
              Kafka (log-events topic)
                        |
                        v
           Prometheus ←────→ Grafana
           (metrics parsed      (dashboards)
            from log events)

INFRASTRUCTURE:
All above runs in Kubernetes (kind for local dev)
K8s faults: OOM kills, pod evictions, node pressure, crashloops
```

---

## Services

| Service          | Tech           | Role                                              |
|------------------|----------------|---------------------------------------------------|
| Frontend         | React          | User-facing app, sends X-Instance-ID on requests  |
| Backend API      | Spring Boot    | Core service, rate limiter, connects to DB/cache  |
| Kafka Consumer   | Python         | Processes item-events, failures go to DLQ         |
| Rust Log Pipeline | Rust          | Reads structured logs, publishes to Kafka, feeds metrics |
| Database         | PostgreSQL     | Sharded persistent storage (hot partition scenario) |
| Cache            | Redis          | Shared state for rate limiter + general caching   |

---

## Tech Stack

| Layer            | Technology                          |
|------------------|-------------------------------------|
| Frontend         | React + TypeScript + Tailwind CSS   |
| Core API         | Spring Boot (Java)                  |
| Event Pipeline   | Kafka + Kafka Consumer (Python)     |
| Log Pipeline     | Rust (tokio, rdkafka)               |
| Agent Service    | Python + FastAPI + LangGraph        |
| LLM              | Ollama (local model)                |
| Vector Store     | ChromaDB                            |
| Database         | PostgreSQL (sharded)                |
| Cache            | Redis                               |
| Metrics          | Prometheus + Grafana                |
| Infrastructure   | Kubernetes (kind for local dev)     |

---

## Failure Scenarios

| Scenario                  | What Breaks                                     | Signal                                      |
|---------------------------|-------------------------------------------------|---------------------------------------------|
| Rate limit storm          | Backend returns 429s in bursts                  | 429 rate in Grafana, jobs queue depth       |
| Kafka DLQ overflow        | Consumer fails repeatedly, DLQ fills up         | DLQ depth metric, consumer lag              |
| Hot database shard        | One shard overwhelmed, queries time out         | Shard-level latency/CPU divergence          |
| Pod OOM kill              | K8s kills a pod for exceeding memory limit      | OOMKilled in pod events, restart count      |
| Pod eviction              | Node pressure causes K8s to evict pods          | Eviction events, service unavailability     |
| Backend crash loop        | Pod keeps crashing and restarting               | CrashLoopBackOff in pod status              |
| Redis outage              | Cache layer fails, DB load spikes               | Cache hit rate drop, DB CPU spike           |

---

## Observability Pipeline Detail

Every service emits structured JSON logs. The Rust log pipeline:
1. Reads log output from each service (via file tail or sidecar)
2. Parses and enriches log events (adds service metadata, severity, timestamps)
3. Publishes to Kafka topic `log-events`
4. A Kafka consumer converts log-derived signals into Prometheus metrics
5. Grafana dashboards visualize error rates, latency, queue depths, shard health

This means Prometheus metrics are derived from log events — the Rust pipeline is the single source of truth for observability, not a sidecar per service.

---

## Database Schema

| Table               | Purpose                                       |
|---------------------|-----------------------------------------------|
| `services`          | Service metadata                              |
| `deployments`       | Deploy history per service                    |
| `incidents`         | Incident records                              |
| `incident_evidence` | Logs/metrics/runbook refs used in diagnosis   |
| `agent_runs`        | Each agent investigation attempt              |
| `approvals`         | User approval decisions for proposed actions  |
| `reports`           | Generated postmortem content                  |
| `audit_log`         | Rate limit violations and other events        |

---

## Folder Structure

```
cloud-incident-lab/
  services/
    backend-app/         # Spring Boot API + rate limiter
    frontend-app/        # React frontend
    kafka-consumer/      # Python Kafka consumer with DLQ logic
    log-pipeline/        # Rust log pipeline (reads logs → Kafka → Prometheus)
  infrastructure/
    k8s/                 # Kubernetes manifests (deployments, services, configmaps)
    kafka/               # Kafka + Zookeeper config
    postgres/            # Sharded PostgreSQL init scripts
    redis/               # Redis config
    prometheus/          # Prometheus scrape config
    grafana/             # Grafana dashboard definitions
  incident-scenarios/    # Scripts that trigger each failure
  scripts/               # Setup, reset, load test helpers
  docs/                  # This folder
  runbooks/              # Markdown runbooks indexed by the agent
```

---

## Why This Project Is Strong for Hiring

- Shows Kubernetes knowledge (real K8s faults, not just Docker)
- Shows distributed systems understanding (Kafka, DLQ, sharding, hot partitions)
- Shows systems programming (Rust log pipeline)
- Shows observability engineering (metrics derived from log pipeline, not just sidecars)
- Shows proper agentic AI (LLM uses tools and makes decisions, not just memory)
- Shows safe AI design (human approval before risky actions)
- Shows product thinking (real use case, dashboard, measurable outputs)

---

## Resume Bullet

> Built an agentic incident-response platform for a Kubernetes-based microservices environment using React, Spring Boot, Rust, Python, Kafka, PostgreSQL (sharded), Redis, Prometheus, Grafana, and LangGraph. Implemented a Rust log-processing pipeline that streams events through Kafka into Prometheus. Designed distributed systems failure scenarios including DLQ overflow, hot database shards, pod OOM kills, and rate limit storms. Built a tool-using AI agent to diagnose root causes across simulated production incidents.



Analyze the docs as i WANT to make the main scope of the plan fixed
you will have multiple failure points
so from the backend things like rate limiting
maybe a queue system which ends up having a lot of failures and goes to dead letter queue
database is sharded but one part gets more calls than anyone
I want a bunch of distributed systems fault happening and that can be through kubernetes and all
all of these logs will be processed by a rust pipeline which will pass the logs through kafka and post the metrics to grafana and prometheus

that is the main scope right now