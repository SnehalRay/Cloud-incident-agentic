#!/usr/bin/env bash
# Connections self-release when pg_sleep expires.
# This script terminates any lingering idle/active backend connections on both shards
# and verifies both shards are responsive.

echo "==> hot-shard-fault: resetting"
echo ""

for shard in 1 2; do
  container="incident-lab-postgres-shard-$shard"
  echo "--- Terminating non-system connections on shard-$shard ---"
  docker exec "$container" psql -U incidentuser -d incidentlab -tAq \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE pid <> pg_backend_pid() AND usename = 'incidentuser';" 2>/dev/null
  echo "    done"
done

echo ""
echo "--- Verifying shards are responsive ---"
for shard in 1 2; do
  container="incident-lab-postgres-shard-$shard"
  result=$(docker exec "$container" psql -U incidentuser -d incidentlab -tAq \
    -c "SELECT 1;" 2>/dev/null)
  if [ "$result" = "1" ]; then
    echo "  shard-$shard: ok"
  else
    echo "  shard-$shard: ERROR — may need restart"
  fi
done

echo ""
echo "==> Reset complete."
