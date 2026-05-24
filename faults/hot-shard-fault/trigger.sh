#!/usr/bin/env bash
# Simulates a hot shard by saturating shard-1's connection pool with slow queries.
#
# Calls /api/debug/overload-shard which launches CONNECTIONS virtual threads on the
# target shard, each running pg_sleep for DURATION ms. While those connections are
# held, normal writes routed to shard-1 queue up and time out.
#
# Usage:
#   ./trigger.sh                                  # defaults: shard=0, 15 conns, 10s
#   SHARD=0 CONNECTIONS=25 DURATION=15000 ./trigger.sh

BACKEND=${BACKEND_URL:-http://localhost:8080}
SHARD=${SHARD:-0}
CONNECTIONS=${CONNECTIONS:-15}
DURATION=${DURATION:-10000}

echo "==> hot-shard-fault: overloading shard-$SHARD with $CONNECTIONS connections for ${DURATION}ms"
echo "    backend: $BACKEND"
echo ""

response=$(curl -s "$BACKEND/api/debug/overload-shard?shard=$SHARD&connections=$CONNECTIONS&duration=$DURATION")
echo "    backend response: $response"
echo ""

echo "--- Probing normal writes while shard-$SHARD is saturated ---"
sleep 1

for i in $(seq 1 5); do
  start=$(date +%s%3N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 12 \
    -X POST "$BACKEND/api/items" \
    -H "Content-Type: application/json" \
    -H "X-Instance-ID: fault-probe" \
    -d "{\"name\": \"shard-probe-$RANDOM\", \"description\": \"hot shard probe\"}" 2>/dev/null)
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  echo "  POST /api/items → HTTP $status  (${elapsed}ms)"
  sleep 1
done

echo ""
echo "==> Connections will release after ${DURATION}ms."
echo "    Watch shard-1 logs:"
echo "    docker logs incident-lab-postgres-shard-1 --tail=20"
echo ""
echo "    Run ./status.sh to monitor impact."
