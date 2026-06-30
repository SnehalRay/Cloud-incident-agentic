#!/usr/bin/env bash
# Drive steady traffic through the load balancer so the fault is visible as a
# drop in throughput. Run this in one terminal, trigger the fault in another.
#
# Usage:
#   ./load.sh                # 60s of GET /api/items at ~5 req/s
#   DURATION=120 ./load.sh   # run for 120s
set -euo pipefail

BACKEND="${BACKEND_URL:-http://localhost:8080}"
DURATION="${DURATION:-60}"

echo "==> lb load: GET $BACKEND/api/items for ${DURATION}s"
end=$(( $(date +%s) + DURATION ))
ok=0
fail=0
while [ "$(date +%s)" -lt "$end" ]; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND/api/items" || echo 000)
    case "$code" in
        200 | 201) ok=$((ok + 1)) ;;
        *) fail=$((fail + 1)) ;;
    esac
    sleep 0.2
done
echo "ok=$ok fail=$fail"
