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

`make up` generates a private `.env`, pulls Core and Dashboard `v1.0.0`, starts the stack, and prints the dashboard key. Core initializes the schema and 30-day retention policy.

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
