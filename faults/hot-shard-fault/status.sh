#!/usr/bin/env bash
# Shows per-shard connection counts and backend write latency

echo "==> hot-shard-fault: shard status"
echo ""

echo "--- Active connections per shard ---"
for shard in 1 2; do
  container="incident-lab-postgres-shard-$shard"
  port=$((5432 + shard))
  count=$(docker exec "$container" psql -U incidentuser -d incidentlab -tAq \
    -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null)
  total=$(docker exec "$container" psql -U incidentuser -d incidentlab -tAq \
    -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null)
  echo "  shard-$shard: active=$count  total=$total"
done

echo ""
echo "--- Write latency probe (5 POSTs) ---"
BACKEND=${BACKEND_URL:-http://localhost:8080}
for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 12 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: status-probe" \
    -d "{\"name\": \"status-probe-$RANDOM\", \"description\": \"status check\"}" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  echo "  POST /api/items → HTTP $status  (${elapsed}ms)"
  sleep 1
done

echo ""
echo "--- Recent backend shard logs ---"
docker compose logs --tail=30 backend 2>/dev/null | grep -E "shard|overload" | tail -10 | sed 's/^/  /'
