#!/usr/bin/env bash
# Show active tc qdisc rules for a container.
#
# Usage: ./status.sh [container]

set -euo pipefail

CONTAINER="${1:-incident-lab-postgres-shard-1}"
IMAGE="incident-lab-tc-fault"

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "tc-fault image not found — no fault has been injected yet."
    exit 0
fi

docker run --rm \
    --privileged \
    --pid=host \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE" \
    show "$CONTAINER"
