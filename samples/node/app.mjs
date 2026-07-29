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
const server = http.createServer((request, response) => {
  const parent = propagation.extract(context.active(), request.headers);
  tracer.startActiveSpan(
    `${request.method} ${request.url}`,
    { kind: SpanKind.SERVER },
    parent,
    (span) => {
      span.setStatus({ code: SpanStatusCode.ERROR, message: "card declined" });
      logger.emit({
        severityNumber: SeverityNumber.ERROR,
        severityText: "ERROR",
        body: "payment declined",
        attributes: { "payment.reason": "demo_card_declined" },
      });
      response.writeHead(503, { "content-type": "text/plain" });
      response.end("payment declined\n");
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
