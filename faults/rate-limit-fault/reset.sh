#!/usr/bin/env bash
# Clears all rate limit keys and violation jobs from Redis.
# Run this after a fault simulation to restore clean state.

echo "==> rate-limit-fault: resetting Redis state"

# Remove all rate limiter counters
keys=$(docker exec incident-lab-redis redis-cli KEYS "rate_limiter:*")
if [ -n "$keys" ]; then
  echo "$keys" | xargs docker exec incident-lab-redis redis-cli DEL
  echo "    cleared rate_limiter keys"
else
  echo "    no rate_limiter keys found"
fi

# Clear the jobs queue
depth=$(docker exec incident-lab-redis redis-cli LLEN jobs:queue)
docker exec incident-lab-redis redis-cli DEL jobs:queue > /dev/null
echo "    cleared jobs:queue ($depth items removed)"

echo "==> Reset complete."
