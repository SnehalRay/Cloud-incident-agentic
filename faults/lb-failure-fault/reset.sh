#!/usr/bin/env bash
# Restore the load balancer.
set -euo pipefail

LB="incident-lab-lb"

echo "=== Resetting LB Failure Fault ==="
if docker inspect "$LB" &>/dev/null; then
    echo "Starting load balancer ($LB)..."
    docker start "$LB" >/dev/null
else
    echo "Container not found; bringing it up via compose..."
    docker compose up -d lb
fi
echo "Load balancer restored."
echo "Verify: curl -s -o /dev/null -w '%{http_code}\\n' http://localhost:8080/api/items"
