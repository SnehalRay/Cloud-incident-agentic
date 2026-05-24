#!/usr/bin/env bash
# Reconnects the partitioned shard to the network and verifies writes succeed again

SHARD=${SHARD:-2}
CONTAINER="incident-lab-postgres-shard-$SHARD"

echo "==> network-partition-fault: restoring shard-$SHARD"

ACTUAL_NETWORK=$(docker network ls --format '{{.Name}}' | grep "incident-lab-network" | head -1)
if [ -z "$ACTUAL_NETWORK" ]; then
  echo "ERROR: could not find incident-lab-network"
  exit 1
fi

docker network connect "$ACTUAL_NETWORK" "$CONTAINER"
echo "    $CONTAINER reconnected to $ACTUAL_NETWORK"

echo "    waiting 3s for backend connection pool to recover..."
sleep 3

echo ""
echo "--- Verifying writes succeed on both shards ---"
BACKEND=${BACKEND_URL:-http://localhost:8080}
success=0; timeout=0
for i in $(seq 1 6); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: reset-probe" \
    -d "{\"name\": \"reset-$RANDOM\", \"description\": \"reset check\"}" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  case $status in
    200|201) ((success++)); echo "  POST → $status  (${elapsed}ms)" ;;
    000|"")  ((timeout++)); echo "  POST → TIMEOUT  (${elapsed}ms)" ;;
    *)                      echo "  POST → $status  (${elapsed}ms)" ;;
  esac
done

echo ""
[ "$timeout" -eq 0 ] \
  && echo "==> All writes succeeding. Reset complete." \
  || echo "==> Still seeing timeouts — HikariCP may need more time. Wait 30s and retry."
