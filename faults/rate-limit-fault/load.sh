#!/usr/bin/env bash
# Continuous rate-limit storm — keeps all three instances hammering POST /api/items
# so Grafana shows a sustained spike rather than a one-shot blip.
#
# Usage:
#   bash faults/rate-limit-fault/load.sh          # runs until Ctrl+C
#   INTERVAL=1 bash faults/rate-limit-fault/load.sh  # slower bursts

BACKEND=${BACKEND_URL:-http://localhost:8080}
INTERVAL=${INTERVAL:-0.3}  # seconds between individual requests per instance
INSTANCES=("instance-a" "instance-b" "instance-c")

echo "==> rate-limit-fault: continuous storm against $BACKEND"
echo "    instances: ${INSTANCES[*]}"
echo "    Ctrl+C to stop"
echo ""

fire_instance() {
  local instance_id=$1
  while true; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BACKEND/api/items" \
      -H "Content-Type: application/json" \
      -H "X-Instance-ID: $instance_id" \
      -d "{\"name\": \"load-item\", \"description\": \"continuous load from $instance_id\"}")
    sleep "$INTERVAL"
  done
}

# Run all instances in parallel background loops
for instance in "${INSTANCES[@]}"; do
  fire_instance "$instance" &
done

# Print live violation counts every 5 seconds
while true; do
  sleep 5
  depth=$(docker exec incident-lab-redis redis-cli LLEN jobs:queue 2>/dev/null)
  echo "  [$(date +%H:%M:%S)] jobs:queue depth = ${depth:-?}"
done
