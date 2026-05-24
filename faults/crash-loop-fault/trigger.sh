#!/usr/bin/env bash
# Triggers a backend crash loop by hitting /api/debug/crash repeatedly.
# Each hit calls System.exit(1) — the JVM dies, Docker restarts the container.
# Hitting it multiple times before the container fully recovers simulates a crash loop.
#
# Usage:
#   ./trigger.sh              # 3 crashes with 4s gap (default)
#   CRASHES=5 GAP=2 ./trigger.sh

BACKEND=${BACKEND_URL:-http://localhost:8080}
CRASHES=${CRASHES:-3}
GAP=${GAP:-4}

echo "==> crash-loop-fault: triggering $CRASHES crashes against $BACKEND"
echo "    gap between hits: ${GAP}s"
echo ""

for i in $(seq 1 "$CRASHES"); do
  echo "--- crash $i of $CRASHES ---"

  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$BACKEND/api/debug/crash" 2>/dev/null)

  if [ "$status" = "000" ] || [ -z "$status" ]; then
    echo "  backend killed (connection dropped — JVM exited)"
  else
    echo "  response: $status"
  fi

  if [ "$i" -lt "$CRASHES" ]; then
    echo "  waiting ${GAP}s before next crash..."
    sleep "$GAP"
  fi
done

echo ""
echo "==> Done. Check restart count:"
echo "    docker inspect --format='{{.RestartCount}}' incident-lab-backend"
echo ""
echo "    Watch container come back:"
echo "    docker compose ps backend"
echo ""
echo "    Recent backend logs:"
echo "    docker compose logs --tail=20 backend"
