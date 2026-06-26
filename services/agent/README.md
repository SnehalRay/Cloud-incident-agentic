# Diagnosis Agent (Phase 3)

A LangGraph agent that queries Prometheus over PromQL and identifies which
distributed-systems fault is currently active in the lab. The reasoning loop is
LLM-driven tool calling: the model decides which PromQL queries to run, reads the
results, and rules out look-alike faults before concluding.

- **Framework:** LangGraph (`create_react_agent`)
- **Model:** open-source `qwen2.5:14b-instruct`, served locally by Ollama — no API keys, fully offline
- **Tools:** `query_prometheus`, `query_prometheus_range`, `list_metric_names`

It knows the nine fault scenarios under [`faults/`](../../faults) and their metric
signatures (see [`agent/prompt.py`](agent/prompt.py)).

## Run it (Docker)

Both `ollama` and `agent` live behind the `agent` compose profile, so they don't
start with the core stack.

```bash
# 1. Bring up the core lab (backend, kafka, prometheus, …) as usual.
# 2. Start Ollama and pull the model once (~9 GB, needs ~10 GB RAM):
docker compose --profile agent up -d ollama
docker compose exec ollama ollama pull qwen2.5:14b-instruct

# 3. Trigger a fault from faults/<scenario>/, then run a diagnosis:
docker compose --profile agent run --rm agent

# Ask a specific question instead of the default sweep:
docker compose --profile agent run --rm agent "Is the DLQ overflowing?"
```

## Run it (local Python)

```bash
cd services/agent
pip install -r requirements.txt
# Point at the published Prometheus port and a host/remote Ollama:
PROMETHEUS_URL=http://localhost:9090 OLLAMA_BASE_URL=http://localhost:11434 \
  python -m agent
```

## Output

The agent streams each tool call and result, then ends with:

```
DIAGNOSIS: <fault name, or "no active fault">
EVIDENCE:  <the PromQL queries and values that prove it>
RULED OUT: <the closest alternative and why the metrics exclude it>
```

## Configuration

| Env var               | Default                   | Purpose                          |
|-----------------------|---------------------------|----------------------------------|
| `PROMETHEUS_URL`      | `http://prometheus:9090`  | Prometheus HTTP API base URL     |
| `OLLAMA_BASE_URL`     | `http://ollama:11434`     | Ollama server base URL           |
| `AGENT_MODEL`         | `qwen2.5:14b-instruct`    | Ollama model tag                 |
| `AGENT_TEMPERATURE`   | `0`                       | Sampling temperature             |
| `AGENT_MAX_ITERATIONS`| `25`                      | Agent loop recursion limit       |
