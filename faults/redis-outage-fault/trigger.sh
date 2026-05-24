#!/usr/bin/env bash
# Stops Redis entirely and shows the cascade across three systems:
#
#   1. Rate limiter   — fails open (all POSTs allowed through, no 429s)
#   2. Cache          — all GET /api/items go directly to the DB (cache miss flood)
#   3. DB load        — both shards receive direct queries with no cache buffer
#
# Usage:
#   ./trigger.sh

BACKEND=${BACKEND_URL:-http://localhost:8080}

echo "==> redis-outage-fault: stopping Redis"
docker stop incident-lab-redis
echo ""

echo "--- Waiting 2s for backend to detect the outage ---"
sleep 2

echo ""
echo "--- Signal 1: Rate limiter fails open ---"
echo "    Firing 6 rapid POSTs from instance-a (limit is 2/2s — should all go through now)"
ok=0; limited=0
for i in $(seq 1 6); do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: instance-a" \
    -d "{\"name\": \"redis-outage-$i\", \"description\": \"fault test\"}" 2>/dev/null)
  case $status in
    200|201) ((ok++)) ;;
    429)     ((limited++)) ;;
  esac
done
echo "    2xx=$ok  429=$limited  (expected: 429=0 — rate limiter failed open)"

echo ""
echo "--- Signal 2: Cache misses flood the DB ---"
echo "    Firing 5 GET /api/items — each should hit the DB directly"
for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$BACKEND/api/items" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  echo "    GET /api/items → HTTP $status  (${elapsed}ms)"
done

echo ""
echo "==> Redis is down. Run ./status.sh to monitor. Run ./reset.sh to restore."
echo ""
echo "    Watch backend logs for cache_get_error and rate_limiter_redis_unavailable:"
echo "    docker compose logs -f backend | grep -E 'cache_|rate_limiter_redis'"
