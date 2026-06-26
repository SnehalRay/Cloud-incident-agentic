"""Runtime configuration, read from the environment."""

import os

# Prometheus HTTP API base URL. Inside docker-compose this is the service name;
# for a local run against the published port use http://localhost:9090.
PROMETHEUS_URL = os.environ.get("PROMETHEUS_URL", "http://prometheus:9090")

# Ollama server base URL. Inside docker-compose this is the service name; for a
# local run against a host Ollama use http://localhost:11434.
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")

# The diagnosis model. Qwen2.5-Instruct has the strongest tool-calling among
# small local models, which the PromQL diagnosis loop depends on.
MODEL = os.environ.get("AGENT_MODEL", "qwen2.5:14b-instruct")

# Sampling temperature — low, because diagnosis should be deterministic.
TEMPERATURE = float(os.environ.get("AGENT_TEMPERATURE", "0"))

# Cap the agent loop so a runaway diagnosis can't spin forever.
MAX_ITERATIONS = int(os.environ.get("AGENT_MAX_ITERATIONS", "25"))
