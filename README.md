# Kanshi demo

Run Kanshi locally from the current release-candidate source. This repository is the fastest self-contained path for testing the dashboard, core, TimescaleDB, and an agent without creating AWS resources.

## Requirements

- Docker with Compose
- OpenSSL

## Start the stack

```sh
git clone https://github.com/kanshi-dev/demo.git
cd demo
cp .env.example .env

db_password=$(openssl rand -hex 32)
ingest_key=$(openssl rand -hex 32)
dashboard_key=$(openssl rand -hex 32)
sed -i.bak "s/generate-db-password/$db_password/; s/generate-ingest-key/$ingest_key/; s/generate-dashboard-key/$dashboard_key/" .env
rm -f .env.bak

docker compose up -d
```

The first start builds Core `v1.0.0-rc3` and Dashboard `v1.0.0-rc4` from their public Git tags. Core initializes the schema and 30-day retention policy.

Open [http://localhost:3000](http://localhost:3000) and enter `KANSHI_DASHBOARD_KEY` from `.env`.

## Install an agent

Use an address reachable from the monitored host:

```sh
curl -fsSL https://kanshi.dev/install.sh |
  KANSHI_VERSION=v1.0.0-rc3 sh

export KANSHI_CORE_ADDR=your-server:50051
export KANSHI_API_KEY=the-ingest-key-from-.env
kanshi-agent
```

For systemd Linux:

```sh
curl -fsSL https://kanshi.dev/install.sh |
  sudo KANSHI_VERSION=v1.0.0-rc3 \
  KANSHI_CORE_ADDR=your-server:50051 \
  KANSHI_API_KEY=the-ingest-key-from-.env \
  sh -s -- --systemd
```

## Verify

```sh
curl http://localhost:8080/health
curl -H "Authorization: Bearer $dashboard_key" \
  http://localhost:8080/api/v1/agents
```

## Screens

### Fleet overview

![Kanshi fleet overview](imgs/agents.png)

### Agent details

![Kanshi agent details](imgs/agent-details.png)

## Stop

```sh
docker compose down
```

Add `-v` only when you also want to delete local metrics.

For the AWS test environment, use the [Terraform demo](https://github.com/kanshi-dev/infra/tree/main/deployment/infra). For component details, see the [Kanshi documentation](https://kanshi.dev/docs/).
