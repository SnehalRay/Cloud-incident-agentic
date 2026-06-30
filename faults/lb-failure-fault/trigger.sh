#!/usr/bin/env bash
# lb-failure-fault: stop the load balancer in front of the backend nodes.
#
# backend-1 and backend-2 stay up and healthy, but with the LB gone nothing
# routes client traffic to them — every request to the host :8080 now fails.
# This exposes the load balancer as a SINGLE POINT OF FAILURE: scaling the
# backend to two nodes does not survive the router itself dying.
#
# Observe in Prometheus:
#   up{job="lb"}                  -> 0   (LB scrape target down)
#   up{job="backend"}             -> 1   (both nodes still healthy)
#   rate(lb_requests_total[1m])   -> flat (nothing is being routed)
set -euo pipefail

LB="incident-lab-lb"

echo "=== LB Failure Fault ==="
if ! docker inspect "$LB" &>/dev/null; then
    echo "Load balancer container '$LB' not found. Is the stack up?"
    exit 1
fi

echo "Stopping load balancer ($LB)..."
docker stop "$LB" >/dev/null
echo ""
echo "Load balancer is DOWN. Backends remain healthy but unreachable from the host."
echo "Run ./status.sh to see the differential, or ./reset.sh to restore."
