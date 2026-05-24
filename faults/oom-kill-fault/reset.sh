#!/usr/bin/env bash
# Remove the mem-pressure container.

set -euo pipefail

CONTAINER="incident-lab-mem-pressure"

if docker inspect "$CONTAINER" &>/dev/null; then
    docker rm -f "$CONTAINER"
    echo "Removed container '$CONTAINER'."
else
    echo "Nothing to reset — container '$CONTAINER' not found."
fi
