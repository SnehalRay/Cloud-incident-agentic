#!/usr/bin/env bash
# Restarts Redis and waits for the backend to reconnect

echo "==> redis-outage-fault: restoring Redis"

docker start incident-lab-redis

echo "    waiting for Redis to accept connections..."
for i in $(seq 1 15); do
  result=$(docker exec incident-lab-redis redis-cli ping 2>/dev/null)
  if [ "$result" = "PONG" ]; then
    echo "    Redis up (${i}s)"
    break
  fi
  sleep 1
done

echo ""
echo "--- Verifying rate limiter is enforcing again ---"
BACKEND=${BACKEND_URL:-http://localhost:8080}
sleep 2  # give backend connection pool a moment to reconnect

ok=0; limited=0
for i in $(seq 1 6); do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: reset-probe" \
    -d "{\"name\": \"reset-$i\", \"description\": \"reset check\"}" 2>/dev/null)
  case $status in
    200|201) ((ok++)) ;;
    429)     ((limited++)) ;;
  esac
done
echo "  2xx=$ok  429=$limited"
[ "$limited" -gt 0 ] && echo "  rate limiter: enforcing (Redis restored)" || echo "  rate limiter: still failing open — Redis may still be reconnecting"

echo ""
echo "==> Reset complete."
