.PHONY: up down reset keys agent-env logs

.env: .env.example
	@set -e; \
	umask 077; \
	cp .env.example .env; \
	db_password=$$(openssl rand -hex 32); \
	ingest_key=$$(openssl rand -hex 32); \
	dashboard_key=$$(openssl rand -hex 32); \
	sed "s/generate-db-password/$$db_password/; s/generate-ingest-key/$$ingest_key/; s/generate-dashboard-key/$$dashboard_key/" .env > .env.tmp; \
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
