#!/usr/bin/env bash
# Shows current rate limit state in Redis — useful to run during or after trigger.sh

echo "==> rate-limit-fault: current Redis state"
echo ""

echo "--- Active rate limit counters ---"
keys=$(docker exec incident-lab-redis redis-cli KEYS "rate_limiter:*")
if [ -n "$keys" ]; then
  while IFS= read -r key; do
    val=$(docker exec incident-lab-redis redis-cli GET "$key")
    ttl=$(docker exec incident-lab-redis redis-cli PTTL "$key")
    echo "  $key  count=$val  ttl=${ttl}ms"
  done <<< "$keys"
else
  echo "  (none)"
fi

echo ""
echo "--- jobs:queue depth ---"
depth=$(docker exec incident-lab-redis redis-cli LLEN jobs:queue)
echo "  queued violations: $depth"

if [ "$depth" -gt 0 ]; then
  echo ""
  echo "--- Last 5 violation jobs ---"
  docker exec incident-lab-redis redis-cli LRANGE jobs:queue -5 -1 | while IFS= read -r line; do
    echo "  $line"
  done
fi
