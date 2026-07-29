# Kanshi demo

Run Kanshi locally from the current stable release. This repository is the fastest self-contained path for testing the dashboard, Core, TimescaleDB, Agent, OpenTelemetry Collector, and instrumented services without creating AWS resources.

## Requirements

- Docker with Compose
- OpenSSL
- curl

## Start the stack

```sh
git clone https://github.com/kanshi-dev/demo.git
cd demo
make up
```

`make up` generates a private `.env`, pulls the stable Kanshi v1.2 release line, builds the sample services and Agent image, starts the stack, and prints the dashboard key. A small Alpine demo driver creates the memory alert rule when missing and generates mixed checkout traffic every 30 seconds. Core initializes the schema with 30-day host metric retention, 7-day trace retention, and 3-day log retention.

Open [http://localhost:3000](http://localhost:3000) and enter the printed dashboard key. Run `make keys` to print it again.

## Try application observability

The Go checkout service and Node.js payment service include the official OpenTelemetry SDKs. They send OTLP traces and correlated logs to the bundled Collector, which authenticates to Core. No local OpenTelemetry installation is required.

```sh
curl http://localhost:8081/checkout
curl "http://localhost:8081/checkout?scenario=slow"
curl "http://localhost:8081/checkout?scenario=declined"
curl "http://localhost:8081/checkout?scenario=error"
```

Requests without a scenario cycle through successful, slow, declined, and unavailable payments. Explicit scenarios return `200`, `402`, or `503`, while an unknown scenario returns `400`. Open the dashboard **Services** page to compare healthy and failed traces, inspect their latency and span waterfalls, and view logs linked to each span.

The stack also runs Kanshi Agent. Its container host appears on the **Agents** page with live CPU and memory metrics.

Run the repeatable end-to-end check:

```sh
make verify
```

It verifies rejected unauthenticated requests, query limits, successful and failed API outcomes, a two-service trace, correlated logs, Agent CPU and memory, and graceful sample service shutdown and restart.

## Try alerting

The demo driver creates an enabled `mem.used_percent > 1` rule. Once the Agent reports real data, Core fires the alert and delivers a signed webhook to the bundled private sink. View the rule, active alert, history, and delivery status on the dashboard **Alerts** page.

Print the delivered webhook:

```sh
make demo-alert
```

`make demo-alert` reads the sink log without creating another rule. Stream future deliveries with `make alert-logs`.

## Screens

### Fleet overview

![Kanshi fleet overview](imgs/agents.png)

### Agent details

![Kanshi agent details](imgs/agent-details.png)

## Stop

```sh
make down
```

Run `make reset` when you also want to delete local telemetry, the Agent identity, and generated keys. A clean-machine repeat is:

```sh
make reset
make up
make verify
```

For the AWS test environment, use the [Terraform demo](https://github.com/kanshi-dev/infra). For component details, see the [Kanshi documentation](https://kanshi.dev/docs/).
