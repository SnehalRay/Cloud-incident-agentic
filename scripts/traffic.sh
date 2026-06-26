#!/usr/bin/env bash
# Sustained background traffic generator for the Cloud Incident Lab.
#
# Unlike the per-fault trigger.sh scripts (which fire a one-shot burst), this
# runs CONCURRENCY parallel workers that hammer the normal endpoints
# continuously — and keeps running after the command returns, until you stop it.
# That sustained load is what makes faults show up as steady, non-decaying
# signals the diagnosis agent can reason about with rate()/increase().
#
# Usage:
#   bash scripts/traffic.sh start        # start, return to prompt, keep running
#   bash scripts/traffic.sh status       # how many workers are alive
#   bash scripts/traffic.sh stop         # stop everything
#
#   CONCURRENCY=100 bash scripts/traffic.sh start    # crank the volume up
#   INTERVAL=0     bash scripts/traffic.sh start     # no pause between requests (max throughput)
#
# Typical test loop:
#   bash scripts/traffic.sh start
#   bash faults/<scenario>/trigger.sh
#   docker compose --profile agent run --rm agent
#   bash scripts/traffic.sh stop
set -uo pipefail

BACKEND=${BACKEND_URL:-http://localhost:8080}
CONCURRENCY=${CONCURRENCY:-20}     # parallel workers; raise for higher volume
INTERVAL=${INTERVAL:-0.05}         # seconds between requests per worker (0 = flat out)
PIDFILE=${PIDFILE:-/tmp/incident-lab-traffic.pids}
INSTANCES=("instance-a" "instance-b" "instance-c")

worker() {
  local id=$1
  local instance=${INSTANCES[$(( id % ${#INSTANCES[@]} ))]}
  while true; do
    if (( RANDOM % 2 )); then
      # read path — exercises cache + DB read path
      curl -s -o /dev/null --max-time 8 \
        -H "X-Instance-ID: $instance" \
        "$BACKEND/api/items" 2>/dev/null
    else
      # write path — exercises rate limiter + DB write path (sharded)
      curl -s -o /dev/null --max-time 8 -X POST \
        -H "Content-Type: application/json" \
        -H "X-Instance-ID: $instance" \
        -d '{"name":"load-item","description":"sustained background traffic"}' \
        "$BACKEND/api/items" 2>/dev/null
    fi
    [[ "$INTERVAL" != "0" ]] && sleep "$INTERVAL"
  done
}

start() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(head -1 "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    echo "traffic already running (pidfile $PIDFILE). Run: $0 stop" >&2
    exit 1
  fi
  : > "$PIDFILE"
  echo "==> starting $CONCURRENCY workers against $BACKEND (interval=${INTERVAL}s)"
  for i in $(seq 1 "$CONCURRENCY"); do
    worker "$i" &
    echo $! >> "$PIDFILE"
  done
  echo "==> running in the background. It will NOT stop until you run: $0 stop"
}

stop() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "no pidfile at $PIDFILE — nothing to stop"
    exit 0
  fi
  echo "==> stopping traffic..."
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    pkill -P "$pid" 2>/dev/null   # kill the worker's in-flight curl child
    kill "$pid" 2>/dev/null       # kill the worker loop itself
  done < "$PIDFILE"
  rm -f "$PIDFILE"
  echo "==> stopped."
}

status() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "not running"
    return
  fi
  local alive=0 total=0
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    (( total++ ))
    kill -0 "$pid" 2>/dev/null && (( alive++ ))
  done < "$PIDFILE"
  echo "running: $alive/$total workers alive against $BACKEND (pidfile $PIDFILE)"
}

case "${1:-}" in
  start)  start ;;
  stop)   stop ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|status}   env: CONCURRENCY (default 20), INTERVAL (default 0.05s), BACKEND_URL" >&2; exit 1 ;;
esac
