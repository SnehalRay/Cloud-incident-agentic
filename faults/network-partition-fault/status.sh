#!/usr/bin/env bash
# Shows network reachability for both shards and the asymmetric write failure pattern

BACKEND=${BACKEND_URL:-http://localhost:8080}

echo "==> network-partition-fault: status"
echo ""

echo "--- Network connectivity per shard ---"
ACTUAL_NETWORK=$(docker network ls --format '{{.Name}}' | grep "incident-lab-network" | head -1)
for shard in 1 2; do
  container="incident-lab-postgres-shard-$shard"
  connected=$(docker network inspect "$ACTUAL_NETWORK" \
    --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -c "$container")
  if [ "$connected" -gt 0 ]; then
    echo "  shard-$shard: CONNECTED to $ACTUAL_NETWORK"
  else
    echo "  shard-$shard: PARTITIONED (disconnected from network)"
  fi
done

echo ""
echo "--- Container health (running but unreachable is the partition signature) ---"
for shard in 1 2; do
  container="incident-lab-postgres-shard-$shard"
  state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
  echo "  shard-$shard container: $state"
done

echo ""
echo "--- Write probe (10 POSTs — asymmetric success/timeout shows which shard is partitioned) ---"
success=0; timeout=0
for i in $(seq 1 10); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: status-probe" \
    -d "{\"name\": \"probe-$RANDOM\", \"description\": \"status\"}" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  case $status in
    200|201) ((success++)); echo "  POST → $status  (${elapsed}ms)" ;;
    000|"")  ((timeout++)); echo "  POST → TIMEOUT  (${elapsed}ms)" ;;
    *)                      echo "  POST → $status  (${elapsed}ms)" ;;
  esac
done
echo ""
echo "  success=$success  timeout=$timeout"
[ "$timeout" -gt 0 ] && echo "  partition active — shard unreachable" || echo "  all writes succeeding — no active partition"
