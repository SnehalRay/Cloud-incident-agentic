#!/usr/bin/env bash
# Simulates a rate limit storm by firing bursts of POST /api/items
# from three frontend instances simultaneously.
#
# Each instance is allowed 2 requests per 2 seconds.
# Firing 10 rapid requests per instance means ~8 per instance will get 429.
# Violations are pushed to jobs:queue in Redis by the backend.
#
# Usage:
#   ./trigger.sh              # uses defaults (localhost:8080, 10 requests per instance)
#   REQUESTS=20 ./trigger.sh  # fire 20 requests per instance

BACKEND=${BACKEND_URL:-http://localhost:8080}
REQUESTS=${REQUESTS:-10}

INSTANCES=("instance-a" "instance-b" "instance-c")

echo "==> rate-limit-fault: firing $REQUESTS requests per instance against $BACKEND"
echo "    instances: ${INSTANCES[*]}"
echo ""

fire_instance() {
  local instance_id=$1
  local ok=0
  local limited=0
  local failed=0

  for i in $(seq 1 "$REQUESTS"); do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BACKEND/api/items" \
      -H "Content-Type: application/json" \
      -H "X-Instance-ID: $instance_id" \
      -d "{\"name\": \"fault-item-$i\", \"description\": \"rate limit test from $instance_id\"}")

    case $status in
      200|201) ((ok++)) ;;
      429)     ((limited++)) ;;
      *)       ((failed++)) ;;
    esac
  done

  echo "  [$instance_id] 2xx=$ok  429=$limited  other=$failed"
}

# Fire all three instances in parallel
for instance in "${INSTANCES[@]}"; do
  fire_instance "$instance" &
done

wait

echo ""
echo "==> Done. Check Redis queue depth:"
echo "    docker exec incident-lab-redis redis-cli LLEN jobs:queue"
echo ""
echo "    View violations:"
echo "    docker exec incident-lab-redis redis-cli LRANGE jobs:queue 0 -1"
