#!/usr/bin/env bash
# Checks backend responsiveness — measures actual response time for a normal request

BACKEND=${BACKEND_URL:-http://localhost:8080}

echo "==> slow-request-fault: backend responsiveness check"
echo ""

echo "--- Timing GET /api/items (5 probes) ---"
for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$BACKEND/api/items" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))

  if [ "$status" = "200" ]; then
    tag="ok"
  elif [ "$status" = "000" ] || [ -z "$status" ]; then
    tag="TIMEOUT"
  else
    tag="ERROR"
  fi

  echo "  probe $i → HTTP $status  ${elapsed}ms  [$tag]"
  sleep 1
done

echo ""
echo "--- Recent slow_request log entries ---"
docker compose logs --tail=50 backend 2>/dev/null | grep "slow_request" | tail -10 | sed 's/^/  /'
