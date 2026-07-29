#!/bin/sh
set -eu

base=http://core:8080/api/v1
auth="Authorization: Bearer $KANSHI_DASHBOARD_KEY"
rule_name="Demo high memory"

rules=$(wget -qO- --header "$auth" "$base/alerts/rules")
if ! printf '%s' "$rules" | grep -q "\"name\":\"$rule_name\""; then
  wget -qO- \
    --header "$auth" \
    --header "Content-Type: application/json" \
    --post-data "{\"name\":\"$rule_name\",\"metric\":\"mem.used_percent\",\"comparator\":\"gt\",\"threshold\":1,\"enabled\":true}" \
    "$base/alerts/rules" >/dev/null
  echo "created alert rule: $rule_name"
fi

echo "generating checkout traffic every ${DEMO_INTERVAL_SECONDS:-30}s"
while true; do
  wget -qO- http://checkout:8081/checkout >/dev/null || true
  sleep "${DEMO_INTERVAL_SECONDS:-30}"
done
