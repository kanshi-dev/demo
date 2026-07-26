.PHONY: up down reset keys agent-env logs demo-alert alert-logs

.env: .env.example
	@set -e; \
	umask 077; \
	cp .env.example .env; \
	db_password=$$(openssl rand -hex 32); \
	ingest_key=$$(openssl rand -hex 32); \
	dashboard_key=$$(openssl rand -hex 32); \
	webhook_secret=$$(openssl rand -hex 32); \
	sed "s/generate-db-password/$$db_password/; s/generate-ingest-key/$$ingest_key/; s/generate-dashboard-key/$$dashboard_key/; s/generate-webhook-secret/$$webhook_secret/" .env > .env.tmp; \
	mv .env.tmp .env
	@echo "Generated .env" >&2

up: .env
	docker compose up -d
	@$(MAKE) --no-print-directory keys

down:
	docker compose down

reset:
	docker compose down -v
	rm -f .env

keys: .env
	@printf 'Dashboard: http://localhost:3000\n'
	@sed -n 's/^KANSHI_DASHBOARD_KEY=/Dashboard key: /p' .env

agent-env: .env
	@printf 'export KANSHI_CORE_ADDR=%s\n' "$${KANSHI_CORE_ADDR:-localhost:50051}"
	@sed -n 's/^KANSHI_API_KEY=/export KANSHI_API_KEY=/p' .env

logs:
	docker compose logs -f

demo-alert: .env
	@key=$$(sed -n 's/^KANSHI_DASHBOARD_KEY=//p' .env); \
	base=http://localhost:8080/api/v1; \
	agent=$$(curl -fsS -H "Authorization: Bearer $$key" $$base/agents | grep -o '"agentId":"[^"]*"' | head -1 | cut -d'"' -f4); \
	if [ -z "$$agent" ]; then echo "No agents are reporting yet. Install an agent (see above) and rerun."; exit 0; fi; \
	if ! curl -fsS -H "Authorization: Bearer $$key" "$$base/metrics/aggregate?agentId=$$agent&name=mem.used_percent&interval=30s" | grep -q '"avgValue"'; then \
		echo "No recent memory metrics from $$agent yet. Wait for it to report and rerun."; exit 0; fi; \
	curl -fsS -X POST $$base/alerts/rules \
		-H "Authorization: Bearer $$key" \
		-H 'Content-Type: application/json' \
		-d '{"name":"Demo high memory","metric":"mem.used_percent","comparator":"gt","threshold":1,"enabled":true}' >/dev/null; \
	printf 'Created a memory alert rule that %s already breaches. Waiting for evaluation...\n' "$$agent"; \
	sleep 15; \
	printf '\n--- alert-sink log (delivered webhook) ---\n'; \
	docker compose logs --tail=20 alert-sink

alert-logs:
	docker compose logs -f alert-sink
