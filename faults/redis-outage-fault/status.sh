#!/usr/bin/env bash
# Shows current state of Redis and the cascade impact on rate limiter + cache + DB

BACKEND=${BACKEND_URL:-http://localhost:8080}

echo "==> redis-outage-fault: current status"
echo ""

echo "--- Redis container state ---"
state=$(docker inspect --format='{{.State.Status}}' incident-lab-redis 2>/dev/null)
echo "  redis: $state"

echo ""
echo "--- Backend health ---"
health=$(curl -s --max-time 3 "$BACKEND/health" 2>/dev/null)
echo "  $health"

echo ""
echo "--- Rate limiter behaviour (6 rapid POSTs — should be 429-free when Redis is down) ---"
ok=0; limited=0; error=0
for i in $(seq 1 6); do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: status-probe" \
    -d "{\"name\": \"status-$RANDOM\", \"description\": \"status check\"}" 2>/dev/null)
  case $status in
    200|201) ((ok++)) ;;
    429)     ((limited++)) ;;
    *)       ((error++)) ;;
  esac
done
echo "  2xx=$ok  429=$limited  other=$error"
[ "$limited" -eq 0 ] && echo "  rate limiter: FAILED OPEN (Redis down)" || echo "  rate limiter: enforcing limits (Redis up)"

echo ""
echo "--- DB connection counts (direct queries landing here due to cache miss) ---"
for shard in 1 2; do
  count=$(docker exec "incident-lab-postgres-shard-$shard" psql -U incidentuser -d incidentlab -tAq \
    -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null)
  echo "  shard-$shard active connections: $count"
done

echo ""
echo "--- Recent cache/rate-limiter error log entries ---"
docker compose logs --tail=50 backend 2>/dev/null \
  | grep -E "cache_get_error|rate_limiter_redis" | tail -8 | sed 's/^/  /'
