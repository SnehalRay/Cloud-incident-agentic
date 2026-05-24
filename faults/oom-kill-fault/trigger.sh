#!/usr/bin/env bash
# Trigger an OOM kill by running mem_pressure inside a memory-capped container.
#
# Usage:
#   ./trigger.sh [memory_limit] [chunk_mb]
#
#   memory_limit — Docker memory cap  (default: 64m)
#   chunk_mb     — allocation step    (default: 10)
#
# The container will be killed by the kernel once it hits the limit.
# Exit code will be 137 (SIGKILL). Docker records OOMKilled=true.
# In Kubernetes: set resources.limits.memory to the same value in the pod spec.

set -euo pipefail

MEM_LIMIT="${1:-64m}"
CHUNK_MB="${2:-10}"
CONTAINER="incident-lab-mem-pressure"
IMAGE="incident-lab-mem-pressure"

echo "=== OOM Kill Fault ==="
echo "Memory limit : $MEM_LIMIT"
echo "Chunk size   : ${CHUNK_MB}MB per step"
echo ""

# Build image if not present
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Building mem-pressure image..."
    docker build -t "$IMAGE" "$(dirname "$0")/../../services/mem-pressure"
    echo ""
fi

# Remove a stale container from a previous run
docker rm -f "$CONTAINER" &>/dev/null || true

echo "Starting container with --memory=$MEM_LIMIT ..."
echo "Watch it allocate until the OOM killer fires (exit 137)."
echo ""

# Run in foreground so the user sees the allocation log and the kill
docker run \
    --name "$CONTAINER" \
    --memory "$MEM_LIMIT" \
    --memory-swap "$MEM_LIMIT" \
    "$IMAGE" \
    "$CHUNK_MB" || true

echo ""
echo "Container stopped. Run ./status.sh to check OOMKilled status."
