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
	@# Seed a fresh CPU sample and a firing rule so Core delivers a signed webhook to the bundled sink.
	@docker compose exec -T db psql -U kanshi -d kanshi -c "INSERT INTO metrics (agent_id, name, value, ts) VALUES ('demo-agent', 'cpu.used_percent', 95, NOW());" >/dev/null
	@curl -fsS -X POST http://localhost:8080/api/v1/alerts/rules \
		-H "Authorization: Bearer $$(sed -n 's/^KANSHI_DASHBOARD_KEY=//p' .env)" \
		-H 'Content-Type: application/json' \
		-d '{"name":"Demo high CPU","metric":"cpu.used_percent","comparator":"gt","threshold":90,"enabled":true}' >/dev/null
	@printf 'Created a firing CPU rule for demo-agent. Waiting for evaluation...\n'
	@sleep 15
	@printf '\n--- alert-sink log (delivered webhook) ---\n'
	@docker compose logs --tail=20 alert-sink

alert-logs:
	docker compose logs -f alert-sink
