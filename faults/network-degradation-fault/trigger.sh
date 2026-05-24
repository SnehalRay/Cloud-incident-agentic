#!/usr/bin/env bash
# Inject tc-netem latency/loss into a container's network namespace.
# Simulates a slow shard without killing the connection — far more realistic
# than docker network disconnect.
#
# Usage:
#   ./trigger.sh [container] [delay_ms] [jitter_ms] [loss_pct]
# Defaults: incident-lab-postgres-shard-1, 200ms delay, 50ms jitter, 1% loss

set -euo pipefail

CONTAINER="${1:-incident-lab-postgres-shard-1}"
DELAY_MS="${2:-200}"
JITTER_MS="${3:-50}"
LOSS_PCT="${4:-1.0}"

echo "=== Network Degradation Fault ==="
echo "Target    : $CONTAINER"
echo "Delay     : ${DELAY_MS}ms ± ${JITTER_MS}ms (normal distribution)"
echo "Packet loss: ${LOSS_PCT}%"
echo ""

# Build / pull the tc-fault image if not present
IMAGE="incident-lab-tc-fault"
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Building tc-fault image..."
    docker build -t "$IMAGE" "$(dirname "$0")/../../services/tc-fault"
fi

docker run --rm \
    --privileged \
    --pid=host \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE" \
    add "$CONTAINER" \
        --delay  "$DELAY_MS" \
        --jitter "$JITTER_MS" \
        --loss   "$LOSS_PCT"

echo ""
echo "Fault active. Run ./status.sh to inspect, ./reset.sh to remove."
