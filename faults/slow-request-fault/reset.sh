#!/usr/bin/env bash
# The slow requests self-resolve once the delay expires (threads are released).
# This script kills any in-flight curl processes and waits for the backend to drain.

echo "==> slow-request-fault: resetting"

# Kill any local curl processes still holding connections
pkill -f "api/debug/slow" 2>/dev/null && echo "    killed in-flight curl processes" || echo "    no in-flight curl processes found"

echo "    waiting for backend thread pool to drain..."
sleep 3

echo ""
echo "--- Probing backend ---"
for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/api/items 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  echo "  GET /api/items → HTTP $status  (${elapsed}ms)"
  [ "$status" = "200" ] && [ "$elapsed" -lt 500 ] && { echo "==> Backend responsive. Reset complete."; exit 0; }
  sleep 1
done

echo "==> Backend still slow — threads may still be draining. Wait for delay to expire or restart:"
echo "    docker compose restart backend"
