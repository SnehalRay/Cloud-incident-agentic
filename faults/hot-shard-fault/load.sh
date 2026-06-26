#!/usr/bin/env bash
# Sustained hot-shard — re-saturates the target shard BEFORE each overload window
# expires, so the shard never recovers and backend_shard_overload_events_total
# climbs continuously. The one-shot trigger.sh saturates for a single DURATION
# window and then the shard recovers; this re-fires forever.
#
# Usage:
#   bash faults/hot-shard-fault/load.sh                                    # runs until Ctrl+C
#   SHARD=0 CONNECTIONS=25 DURATION=15000 bash faults/hot-shard-fault/load.sh
BACKEND=${BACKEND_URL:-http://localhost:8080}
SHARD=${SHARD:-0}
CONNECTIONS=${CONNECTIONS:-15}
DURATION=${DURATION:-10000}           # ms per overload window

# Re-fire at ~80% of the window so the shard is re-saturated before it recovers.
RESLEEP=$(awk "BEGIN { printf \"%.2f\", ($DURATION/1000) * 0.8 }")

echo "==> hot-shard-fault: sustained — re-overloading shard-$SHARD"
echo "    $CONNECTIONS connections, ${DURATION}ms windows, re-fire every ${RESLEEP}s"
echo "    backend: $BACKEND"
echo "    Ctrl+C to stop"
echo ""

count=0
while true; do
  # overload-shard launches server-side virtual threads and returns quickly,
  # so a foreground call here doesn't block the re-fire cadence.
  curl -s -o /dev/null \
    "$BACKEND/api/debug/overload-shard?shard=$SHARD&connections=$CONNECTIONS&duration=$DURATION" 2>/dev/null
  count=$(( count + 1 ))
  echo "  [$(date +%H:%M:%S)] overload window #$count fired on shard-$SHARD"
  sleep "$RESLEEP"
done
