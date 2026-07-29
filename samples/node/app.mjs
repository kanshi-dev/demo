import http from "node:http";
import process from "node:process";

import { context, propagation, SpanKind, SpanStatusCode, trace } from "@opentelemetry/api";
import { SeverityNumber } from "@opentelemetry/api-logs";
import { OTLPLogExporter } from "@opentelemetry/exporter-logs-otlp-grpc";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-grpc";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { BatchLogRecordProcessor, LoggerProvider } from "@opentelemetry/sdk-logs";
import { BatchSpanProcessor, NodeTracerProvider } from "@opentelemetry/sdk-trace-node";
import { ATTR_SERVICE_NAME } from "@opentelemetry/semantic-conventions";

const resource = resourceFromAttributes({ [ATTR_SERVICE_NAME]: "payments" });
const traceProvider = new NodeTracerProvider({
  resource,
  spanProcessors: [new BatchSpanProcessor(new OTLPTraceExporter())],
});
traceProvider.register();

const loggerProvider = new LoggerProvider({
  resource,
  processors: [new BatchLogRecordProcessor({ exporter: new OTLPLogExporter() })],
});

const tracer = trace.getTracer("payments");
const logger = loggerProvider.getLogger("payments");
const outcomes = {
  success: { status: 200, delay: 40, severity: SeverityNumber.INFO, body: "payment approved" },
  slow: { status: 200, delay: 750, severity: SeverityNumber.INFO, body: "payment approved after review" },
  declined: { status: 402, delay: 80, severity: SeverityNumber.WARN, body: "payment declined" },
  error: { status: 503, delay: 120, severity: SeverityNumber.ERROR, body: "payment provider unavailable" },
};
const defaultScenarios = ["success", "success", "slow", "declined", "success", "error"];
let requestCount = 0;

function outcomeFor(request) {
  const scenario = new URL(request.url, "http://payments").searchParams.get("scenario");
  if (!scenario) {
    return outcomes[defaultScenarios[requestCount++ % defaultScenarios.length]];
  }
  return (
    outcomes[scenario] ?? {
      status: 400,
      delay: 0,
      severity: SeverityNumber.WARN,
      body: "unknown payment scenario",
    }
  );
}

const server = http.createServer((request, response) => {
  const parent = propagation.extract(context.active(), request.headers);
  const outcome = outcomeFor(request);
  tracer.startActiveSpan(
    `${request.method} ${request.url}`,
    { kind: SpanKind.SERVER },
    parent,
    async (span) => {
      await new Promise((resolve) => setTimeout(resolve, outcome.delay));
      if (outcome.status >= 400) {
        span.setStatus({ code: SpanStatusCode.ERROR, message: outcome.body });
      }
      logger.emit({
        severityNumber: outcome.severity,
        body: outcome.body,
        attributes: { "http.response.status_code": outcome.status },
      });
      response.writeHead(outcome.status, { "content-type": "text/plain" });
      response.end(`${outcome.body}\n`);
      span.end();
    },
  );
});

server.listen(8082, () => console.log("payments listening on :8082"));

async function shutdown() {
  server.close();
  await loggerProvider.shutdown();
  await traceProvider.shutdown();
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
