#!/bin/sh
set -eu

key=$(sed -n 's/^KANSHI_DASHBOARD_KEY=//p' .env)
demo_agent_id=$(sed -n 's/^DEMO_AGENT_ID=//p' .env)
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
  expected_status=$3
  attempts=0
  until [ "$(curl -sS -o /dev/null -w '%{http_code}' "$url")" = "$expected_status" ]; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "Timed out waiting for $label" >&2
      exit 1
    fi
    sleep 2
  done
  echo "verified: $label"
}

latest_checkout_trace() {
  curl -fsS -H "$auth" "$base/traces?service=checkout" |
    grep -o '"traceId":"[0-9a-f]*"' |
    head -1 |
    cut -d'"' -f4 || true
}

[ "$(curl -sS -o /dev/null -w '%{http_code}' "$base/services")" = 401 ]
[ "$(curl -sS -o /dev/null -w '%{http_code}' -H "$auth" "$base/traces?limit=501")" = 400 ]
echo "verified: authentication and query limits"

previous_trace_id=$(latest_checkout_trace)
wait_for_http "successful checkout request" "http://localhost:8081/checkout?scenario=success" 200
wait_for "checkout service" "$base/services" '"serviceName":"checkout"'
wait_for "payments service" "$base/services" '"serviceName":"payments"'
wait_for "service host link" "$base/services" "\"agentId\":\"$demo_agent_id\",\"hostName\":\"kanshi-demo\""

attempts=0
trace_id=$(latest_checkout_trace)
while [ -z "$trace_id" ] || [ "$trace_id" = "$previous_trace_id" ]; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 30 ]; then
    echo "Timed out waiting for a new checkout trace" >&2
    exit 1
  fi
  sleep 2
  trace_id=$(latest_checkout_trace)
done
[ "${#trace_id}" = 32 ]
wait_for "two-service trace" "$base/traces/$trace_id" '"serviceName":"payments"'
wait_for "trace span host link" "$base/traces/$trace_id" "\"host\":{\"agentId\":\"$demo_agent_id\",\"hostName\":\"kanshi-demo\"}"
wait_for "correlated checkout log" "$base/logs?traceId=$trace_id" '"body":"checkout completed"'
wait_for "correlated payment log" "$base/logs?traceId=$trace_id" '"body":"payment approved"'

[ "$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost:8081/checkout?scenario=declined")" = 402 ]
[ "$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost:8081/checkout?scenario=error")" = 503 ]
[ "$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost:8081/checkout?scenario=unknown")" = 400 ]
echo "verified: varied API outcomes"

wait_for "reporting agent" "$base/agents" '"agentId":"'
agents=$(curl -fsS -H "$auth" "$base/agents")
agent_id=$(printf '%s' "$agents" | sed -n 's/.*"agentId":"\([^"]*\)".*/\1/p' | head -1)
[ "$agent_id" = "$demo_agent_id" ]
agent_version=$(printf '%s' "$agents" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1)
[ "$agent_version" = "$AGENT_VERSION" ]
printf '%s' "$agents" | grep -q '"hostName":"kanshi-demo"'
echo "verified: Agent navigation identity and version"
wait_for "CPU metrics" "$base/metrics/aggregate?agentId=$agent_id&name=cpu.used_percent&interval=30s" '"avgValue":'
wait_for "memory metrics" "$base/metrics/aggregate?agentId=$agent_id&name=mem.used_percent&interval=30s" '"avgValue":'
wait_for "network send metrics" "$base/metrics/aggregate?agentId=$agent_id&name=net.bytes_sent_per_second&interval=30s" '"avgValue":'
wait_for "network receive metrics" "$base/metrics/aggregate?agentId=$agent_id&name=net.bytes_recv_per_second&interval=30s" '"avgValue":'
wait_for "process count" "$base/metrics?agentId=$agent_id&name=process.count" '"name":"process.count"'
wait_for "process CPU" "$base/metrics?agentId=$agent_id&name=process.cpu_percent" '"name":"process.cpu_percent"'
wait_for "process RSS" "$base/metrics?agentId=$agent_id&name=process.memory_rss_bytes" '"name":"process.memory_rss_bytes"'
wait_for "automatic alert rule" "$base/alerts/rules" '"name":"Demo high memory"'
wait_for "automatic alert firing" "$base/alerts/events?limit=100" '"ruleName":"Demo high memory"'
wait_for "delivered alert webhook" "$base/alerts/events?limit=100" '"webhookStatus":"delivered"'

docker compose stop -t 10 checkout payments >/dev/null
docker compose up -d checkout payments >/dev/null
wait_for_http "graceful service restart" "http://localhost:8081/checkout?scenario=success" 200

echo "Application observability demo verified."
