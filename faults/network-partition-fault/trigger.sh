#!/usr/bin/env bash
# Severs shard-2 from the Docker network — simulates a network partition.
#
# This is different from stopping the container:
#   - Container is still running and healthy from its own perspective
#   - Backend gets connection timeouts, not connection refused
#   - ~50% of writes hang (those routed to shard-2) while the other 50% succeed
#   - The asymmetry is the key signal: partial availability, not total failure
#
# Usage:
#   ./trigger.sh
#   SHARD=1 ./trigger.sh   # partition shard-1 instead (0-indexed: shard-1 = postgres-shard-1)

BACKEND=${BACKEND_URL:-http://localhost:8080}
SHARD=${SHARD:-2}
CONTAINER="incident-lab-postgres-shard-$SHARD"
NETWORK="cloud-incident-lab_incident-lab-network"

echo "==> network-partition-fault: disconnecting $CONTAINER from network"

# Resolve the actual network name (Docker Compose prefixes with project name)
ACTUAL_NETWORK=$(docker network ls --format '{{.Name}}' | grep "incident-lab-network" | head -1)
if [ -z "$ACTUAL_NETWORK" ]; then
  echo "ERROR: could not find incident-lab-network. Is docker compose up?"
  exit 1
fi

echo "    network: $ACTUAL_NETWORK"
docker network disconnect "$ACTUAL_NETWORK" "$CONTAINER"
echo "    $CONTAINER disconnected"
echo ""

echo "--- Firing 10 writes — ~50%% will timeout (shard-$SHARD items) ---"
echo "    (curl capped at 6s; backend itself will wait up to 30s for HikariCP)"
echo ""

success=0; timeout=0; other=0
for i in $(seq 1 10); do
  name="item-fault-$RANDOM"
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: partition-probe" \
    -d "{\"name\": \"$name\", \"description\": \"partition test\"}" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))

  case $status in
    200|201)
      ((success++))
      echo "  [$i] $name → HTTP $status  (${elapsed}ms)  [ok — shard-1]"
      ;;
    000|"")
      ((timeout++))
      echo "  [$i] $name → TIMEOUT       (${elapsed}ms)  [shard-$SHARD partitioned]"
      ;;
    *)
      ((other++))
      echo "  [$i] $name → HTTP $status  (${elapsed}ms)"
      ;;
  esac
done

echo ""
echo "  results: success=$success  timeout=$timeout  other=$other"
echo ""
echo "==> Shard-$SHARD is partitioned. Run ./status.sh to monitor. Run ./reset.sh to restore."
echo ""
echo "    Watch backend logs for connection timeout errors:"
echo "    docker compose logs -f backend | grep -iE 'timeout|shard'"
