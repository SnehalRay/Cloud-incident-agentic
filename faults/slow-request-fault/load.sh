#!/usr/bin/env bash
# Sustained slow-request storm — keeps WORKERS slow requests in flight AT ALL
# TIMES so the Tomcat thread pool stays exhausted and backend_slow_requests_total
# climbs continuously. The one-shot trigger.sh only fills the pool once (the
# threads free after DELAY ms and the signal decays); this re-fires forever.
#
# Usage:
#   bash faults/slow-request-fault/load.sh              # runs until Ctrl+C
#   WORKERS=50 DELAY=15000 bash faults/slow-request-fault/load.sh
BACKEND=${BACKEND_URL:-http://localhost:8080}
WORKERS=${WORKERS:-20}
DELAY=${DELAY:-10000}                 # ms each request holds a thread
MAXTIME=$(( DELAY / 1000 + 30 ))      # curl timeout must exceed DELAY

echo "==> slow-request-fault: sustained — $WORKERS threads held continuously (${DELAY}ms each)"
echo "    backend: $BACKEND"
echo "    Ctrl+C to stop"
echo ""

# Each loop keeps exactly one slow request in flight: fire, block until it
# returns (~DELAY ms), fire again. WORKERS loops => WORKERS threads always tied up.
hold_thread() {
  while true; do
    curl -s -o /dev/null --max-time "$MAXTIME" \
      "$BACKEND/api/debug/slow?delay=$DELAY" 2>/dev/null
  done
}

pids=()
for i in $(seq 1 "$WORKERS"); do
  hold_thread &
  pids+=($!)
done

cleanup() {
  echo ""
  echo "==> stopping — releasing held threads..."
  for p in "${pids[@]}"; do
    pkill -P "$p" 2>/dev/null
    kill "$p" 2>/dev/null
  done
  exit 0
}
trap cleanup INT TERM

while true; do
  sleep 5
  echo "  [$(date +%H:%M:%S)] $WORKERS slow requests held in flight against $BACKEND"
done
