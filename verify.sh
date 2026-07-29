#!/bin/sh
set -eu

key=$(sed -n 's/^KANSHI_DASHBOARD_KEY=//p' .env)
base=http://localhost:8080/api/v1
auth="Authorization: Bearer $key"

wait_for() {
  label=$1
  url=$2
  pattern=$3
  attempts=0
  until curl -fsS -H "$auth" "$url" | grep -q "$pattern"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "Timed out waiting for $label" >&2
      exit 1
    fi
    sleep 2
  done
  echo "verified: $label"
}

wait_for_http() {
  label=$1
  url=$2
  attempts=0
  until curl -sS -o /dev/null "$url"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "Timed out waiting for $label" >&2
      exit 1
    fi
    sleep 2
  done
  echo "verified: $label"
}

[ "$(curl -sS -o /dev/null -w '%{http_code}' "$base/services")" = 401 ]
[ "$(curl -sS -o /dev/null -w '%{http_code}' -H "$auth" "$base/traces?limit=501")" = 400 ]
echo "verified: authentication and query limits"

wait_for_http "checkout request" http://localhost:8081/checkout
wait_for "checkout service" "$base/services" '"serviceName":"checkout"'
wait_for "payments service" "$base/services" '"serviceName":"payments"'

traces=$(curl -fsS -H "$auth" "$base/traces?service=checkout")
trace_id=$(printf '%s' "$traces" | grep -o '"traceId":"[0-9a-f]*"' | head -1 | cut -d'"' -f4)
[ "${#trace_id}" = 32 ]
wait_for "two-service trace" "$base/traces/$trace_id" '"serviceName":"payments"'
wait_for "correlated checkout log" "$base/logs?traceId=$trace_id" '"body":"checkout completed"'
wait_for "correlated payment log" "$base/logs?traceId=$trace_id" '"body":"payment declined"'

wait_for "reporting agent" "$base/agents" '"agentId":"'
agents=$(curl -fsS -H "$auth" "$base/agents")
agent_id=$(printf '%s' "$agents" | sed -n 's/.*"agentId":"\([^"]*\)".*/\1/p' | head -1)
wait_for "CPU metrics" "$base/metrics/aggregate?agentId=$agent_id&name=cpu.used_percent&interval=30s" '"avgValue":'
wait_for "memory metrics" "$base/metrics/aggregate?agentId=$agent_id&name=mem.used_percent&interval=30s" '"avgValue":'

docker compose kill -s SIGTERM checkout payments >/dev/null
docker compose up -d checkout payments >/dev/null
wait_for_http "graceful service restart" http://localhost:8081/checkout

echo "Application observability demo verified."
