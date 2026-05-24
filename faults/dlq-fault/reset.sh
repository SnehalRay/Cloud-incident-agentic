#!/usr/bin/env bash
# Restore the healthy consumer (CONSUMER_FAIL_RATE=0.0) and drain the DLQ.

set -euo pipefail

KAFKA="incident-lab-kafka"

echo "=== Resetting DLQ Fault ==="

# Stop the faulty consumer
docker stop incident-lab-kafka-consumer 2>/dev/null || true
docker rm   incident-lab-kafka-consumer 2>/dev/null || true

# Restart the healthy consumer via docker compose
echo "Restarting healthy consumer (CONSUMER_FAIL_RATE=0.0)..."
docker compose up -d --no-deps kafka-consumer

echo ""

# Delete and recreate the DLT topic to drain it
if docker inspect "$KAFKA" &>/dev/null; then
    echo "Draining item-events.DLT..."
    docker exec "$KAFKA" kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --delete --topic item-events.DLT 2>/dev/null || true
    echo "DLT topic deleted — it will be recreated empty on next write."
fi

echo ""
echo "Reset complete. Consumer is healthy, DLQ drained."
