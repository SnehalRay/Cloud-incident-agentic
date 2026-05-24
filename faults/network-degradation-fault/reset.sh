#!/usr/bin/env bash
# Remove tc-netem rules from a container, restoring normal network behaviour.
#
# Usage: ./reset.sh [container]

set -euo pipefail

CONTAINER="${1:-incident-lab-postgres-shard-1}"
IMAGE="incident-lab-tc-fault"

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "tc-fault image not found — nothing to reset."
    exit 0
fi

echo "Removing netem rules from '$CONTAINER'..."
docker run --rm \
    --privileged \
    --pid=host \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE" \
    del "$CONTAINER"

echo "Network restored."
