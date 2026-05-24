#!/usr/bin/env bash
# Show the OOMKilled flag and exit code of the last mem-pressure run.

set -euo pipefail

CONTAINER="incident-lab-mem-pressure"

if ! docker inspect "$CONTAINER" &>/dev/null; then
    echo "No mem-pressure container found. Run ./trigger.sh first."
    exit 0
fi

OOM_KILLED=$(docker inspect --format='{{.State.OOMKilled}}' "$CONTAINER")
EXIT_CODE=$(docker inspect --format='{{.State.ExitCode}}' "$CONTAINER")
STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER")

echo "=== OOM Kill Status ==="
echo "Container : $CONTAINER"
echo "Status    : $STATUS"
echo "Exit code : $EXIT_CODE  (137 = SIGKILL)"
echo "OOMKilled : $OOM_KILLED"
echo ""

if [ "$OOM_KILLED" = "true" ]; then
    echo "OOM kill confirmed. Kubernetes equivalent: pod reason=OOMKilled"
    echo "PromQL (K8s): kube_pod_container_status_last_terminated_reason{reason=\"OOMKilled\"}"
else
    echo "OOM kill not recorded (container may still be running or exited normally)."
fi
