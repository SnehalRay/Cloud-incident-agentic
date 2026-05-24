#!/usr/bin/env bash
# Shows crash loop state — restart count, container status, recent logs

echo "==> crash-loop-fault: current status"
echo ""

echo "--- Container state ---"
docker inspect --format='  status={{.State.Status}}  restarts={{.RestartCount}}  started={{.State.StartedAt}}' incident-lab-backend 2>/dev/null || echo "  container not found"

echo ""
echo "--- Health check ---"
status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://localhost:8080/health 2>/dev/null)
if [ "$status" = "200" ]; then
  echo "  backend healthy (HTTP 200)"
elif [ "$status" = "000" ] || [ -z "$status" ]; then
  echo "  backend unreachable (likely restarting)"
else
  echo "  backend returned HTTP $status"
fi

echo ""
echo "--- Recent logs (last 15 lines) ---"
docker compose logs --tail=15 backend 2>/dev/null | sed 's/^/  /'
