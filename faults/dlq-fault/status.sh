#!/usr/bin/env bash
# Show current DLQ depth and consumer lag via kafka-topics.sh inside the
# Kafka container.

set -euo pipefail

KAFKA="incident-lab-kafka"

if ! docker inspect "$KAFKA" &>/dev/null; then
    echo "Kafka container not running."
    exit 1
fi

echo "=== DLQ Fault Status ==="
echo ""

echo "── Topic offsets (end offset = total messages written) ──"
docker exec "$KAFKA" kafka-run-class.sh kafka.tools.GetOffsetShell \
    --bootstrap-server localhost:9092 \
    --topic item-events \
    --time -1 2>/dev/null || echo "  item-events: (no messages yet)"

docker exec "$KAFKA" kafka-run-class.sh kafka.tools.GetOffsetShell \
    --bootstrap-server localhost:9092 \
    --topic item-events.DLT \
    --time -1 2>/dev/null || echo "  item-events.DLT: (empty)"

echo ""
echo "── Consumer group lag ──"
docker exec "$KAFKA" kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --group item-events-consumer \
    --describe 2>/dev/null || echo "  (consumer group not yet registered)"

echo ""
echo "PromQL queries for the agent:"
echo "  kafka_consumergroup_lag{topic=\"item-events\"}            — consumer falling behind"
echo "  kafka_topic_partition_current_offset{topic=\"item-events.DLT\"} — DLQ depth"
