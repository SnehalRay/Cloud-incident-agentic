#!/usr/bin/env bash
# Simulates thread pool exhaustion by flooding the backend with slow requests.
#
# Each /api/debug/slow request holds a thread for DELAY ms.
# Spring Boot's default Tomcat thread pool is ~200 threads.
# Firing WORKERS concurrent slow requests ties up that many threads.
# While they're blocked, normal /api/items requests queue up and time out.
#
# Usage:
#   ./trigger.sh                        # 20 slow requests, 10s delay each
#   WORKERS=50 DELAY=15000 ./trigger.sh # heavier load

BACKEND=${BACKEND_URL:-http://localhost:8080}
WORKERS=${WORKERS:-20}
DELAY=${DELAY:-10000}

echo "==> slow-request-fault: firing $WORKERS concurrent requests with ${DELAY}ms delay"
echo "    backend: $BACKEND"
echo ""

echo "--- Firing slow requests in background ---"
for i in $(seq 1 "$WORKERS"); do
  curl -s -o /dev/null "$BACKEND/api/debug/slow?delay=$DELAY" &
done

echo "    $WORKERS slow requests in flight, each holding a thread for ${DELAY}ms"
echo ""
echo "--- Probing normal endpoint while threads are blocked ---"
sleep 1

for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BACKEND/api/items" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  echo "  GET /api/items → HTTP $status  (${elapsed}ms)"
  sleep 1
done

echo ""
echo "==> Slow requests still running in background. Threads will free after ${DELAY}ms."
echo "    Watch logs for slow_request_complete entries:"
echo "    docker compose logs -f backend | grep slow_request"
echo ""
echo "    Run ./status.sh to check backend responsiveness."
