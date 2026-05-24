#!/usr/bin/env bash
# Restarts the backend container cleanly and waits for it to become healthy

echo "==> crash-loop-fault: resetting backend"

docker compose restart backend

echo "    waiting for backend to become healthy..."
for i in $(seq 1 15); do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:8080/health 2>/dev/null)
  if [ "$status" = "200" ]; then
    echo "    backend healthy (${i}s)"
    break
  fi
  sleep 1
done

echo ""
echo "--- Final state ---"
docker inspect --format='  status={{.State.Status}}  restarts={{.RestartCount}}' incident-lab-backend
echo "==> Reset complete."
