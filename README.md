# Kanshi demo

Run Kanshi locally from the current stable release. This repository is the fastest self-contained path for testing the dashboard, core, TimescaleDB, and an agent without creating AWS resources.

## Requirements

- Docker with Compose
- OpenSSL

## Start the stack

```sh
git clone https://github.com/kanshi-dev/demo.git
cd demo
make up
```

`make up` generates a private `.env`, pulls Core and Dashboard `v1.1.0`, starts the stack, and prints the dashboard key. Core initializes the schema and 30-day retention policy.

Open [http://localhost:3000](http://localhost:3000) and enter the printed dashboard key. Run `make keys` to print it again.

## Install an agent

Use an address reachable from the monitored host:

```sh
curl -fsSL https://kanshi.dev/install.sh |
  KANSHI_VERSION=v1.0.0 sh

eval "$(KANSHI_CORE_ADDR=your-server:50051 make agent-env)"
kanshi-agent
```

For systemd Linux:

```sh
curl -fsSL https://kanshi.dev/install.sh |
  sudo KANSHI_VERSION=v1.0.0 \
  KANSHI_CORE_ADDR=your-server:50051 \
  KANSHI_API_KEY=the-ingest-key-from-.env \
  sh -s -- --systemd
```

## Try alerting

The stack ships a bundled webhook sink and configures Core to deliver signed alert webhooks to it. Once an agent is reporting (see above), fire a sample alert on real data:

```sh
make demo-alert
```

This checks for a reporting agent and its memory metrics, creates an enabled `mem.used_percent > 1` rule that live data breaches, and prints the signed webhook Core delivers, including its `X-Kanshi-Signature`. If no agent is reporting yet, it says so instead of fabricating data. Manage rules and watch active alerts and history on the dashboard **Alerts** page, and stream deliveries with `make alert-logs`.

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
make down
```

Run `make reset` when you also want to delete local metrics and regenerate keys on the next start.

For the AWS test environment, use the [Terraform demo](https://github.com/kanshi-dev/infra). For component details, see the [Kanshi documentation](https://kanshi.dev/docs/).
