#!/usr/bin/env bash
# Show the three signals that distinguish an LB failure from backends-down or
# simply no-traffic. Reads straight from the Prometheus HTTP API.
set -euo pipefail

PROM="${PROMETHEUS_URL:-http://localhost:9090}"

q() {
    # Instant query -> compact "label => value" lines (falls back to raw JSON
    # if jq is not installed).
    curl -s --get "$PROM/api/v1/query" --data-urlencode "query=$1" \
        | (jq -r '.data.result[] | "  \(.metric.instance // .metric.upstream // "value") => \(.value[1])"' 2>/dev/null \
            || cat)
}

echo "=== LB Failure Fault Status ==="
echo ""
echo "-- LB scrape target  up{job=\"lb\"}  (0 = LB process is down) --"
q 'up{job="lb"}'
echo ""
echo "-- Backend nodes  up{job=\"backend\"}  (1 each = nodes healthy) --"
q 'up{job="backend"}'
echo ""
echo "-- Per-upstream request rate  sum by(upstream)(rate(lb_requests_total[1m]))  (flat = no routing) --"
q 'sum by (upstream) (rate(lb_requests_total[1m]))'
echo ""
echo "-- Upstream health as seen by the LB  lb_upstream_up --"
q 'lb_upstream_up'
echo ""
echo "Interpretation:"
echo "  LB down       : up{job=lb}=0, up{job=backend}=1,1  -> router dead, compute healthy"
echo "  Backends dead : up{job=lb}=1, up{job=backend}=0,0"
echo "  No traffic    : all up=1, request rate ~0"
