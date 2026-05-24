#!/usr/bin/env bash
# Trigger the DLQ overflow fault by restarting the Kafka consumer with a high
# failure rate. 90% of messages will exhaust retries and land in item-events.DLT.
#
# Usage: ./trigger.sh [fail_rate]   (default: 0.9)

set -euo pipefail

FAIL_RATE="${1:-0.9}"

echo "=== DLQ Overflow Fault ==="
echo "Consumer fail rate : $FAIL_RATE"
echo "Max retries        : 3"
echo "Expected DLQ fill  : ~$(echo "$FAIL_RATE * 100" | bc)% of messages"
echo ""

# Stop the healthy consumer
docker stop incident-lab-kafka-consumer 2>/dev/null || true
docker rm   incident-lab-kafka-consumer 2>/dev/null || true

# Start a faulty consumer with the high fail rate
echo "Starting faulty consumer (CONSUMER_FAIL_RATE=$FAIL_RATE)..."
docker run -d \
    --name incident-lab-kafka-consumer \
    --network incident-lab-network \
    --env KAFKA_BROKERS=kafka:9092 \
    --env CONSUMER_FAIL_RATE="$FAIL_RATE" \
    --env MAX_RETRIES=3 \
    incident-lab-kafka-consumer

echo ""
echo "Faulty consumer running. Create some items via the API to generate traffic:"
echo "  curl -s -X POST http://localhost:8080/api/items -H 'Content-Type: application/json' -d '{\"name\":\"test\"}'"
echo ""
echo "Then run ./status.sh to watch the DLQ fill up."
