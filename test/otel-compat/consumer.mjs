import assert from "node:assert/strict";
import { setup } from "@frontman-ai/nextjs/Instrumentation";
import * as api from "@opentelemetry/api";
import { NodeSDK } from "@opentelemetry/sdk-node";
import * as Sentry from "@sentry/nextjs";

process.exitCode = 1;
let passed = false;
const { logs } = "logs" in api ? api : await import("@opentelemetry/api-logs");
const [logProcessor, spanProcessor] = setup();
const sentryClient = Sentry.getClient();
if (sentryClient) {
  sentryClient.getOptions().enabled = false;
}
const enabled = process.env.FRONTMAN_ENABLED === "1";
const legacy = process.env.OTEL_SDK_VERSION === "0.52.0";
const sdk = new NodeSDK({
  spanProcessors: [spanProcessor],
  ...(legacy ? { logRecordProcessor: logProcessor } : { logRecordProcessors: [logProcessor] }),
});

try {
  assert.equal(Sentry.isInitialized(), enabled);
  if (enabled) {
    assert.equal(sentryClient.getOptions().enableOpenTelemetrySetup, false);
  }
  sdk.start();
  const tracer = api.trace.getTracer("frontman-compat");
  const logger = logs.getLogger("frontman-compat");
  const emitSpan = (route, status) => {
    const span = tracer.startSpan(`GET ${route}`);
    assert.equal(span.isRecording(), true);
    span.setAttribute("next.span_type", "BaseServer.handleRequest");
    span.setAttribute("http.method", "GET");
    span.setAttribute("http.route", route);
    span.setAttribute("http.status_code", status);
    span.end();
  };
  emitSpan("/otel-compat", 200);
  emitSpan("/otel-failure", 500);
  emitSpan("/frontman/logs", 200);
  logger.emit({
    body: "otel compatibility error",
    severityText: "ERROR",
    severityNumber: 17,
    attributes: { "compat.attribute": "preserved" },
  });
  await Promise.all([spanProcessor.forceFlush(), logProcessor.forceFlush()]);

  const entries = globalThis.__FRONTMAN_CORE_INSTANCE__?.buffer.contents.data.filter(Boolean) ?? [];
  const requests = entries.filter(entry => entry.attributes?.["log.origin"] === "opentelemetry-span");
  const records = entries.filter(entry => entry.message === "otel compatibility error");
  assert.equal(requests.length, enabled ? 2 : 0);
  assert.equal(records.length, enabled ? 1 : 0);
  if (enabled) {
    const request = requests.find(entry => entry.attributes["http.route"] === "/otel-compat");
    assert.match(request.message, /^GET \/otel-compat 200 [\d.]+ms$/);
    assert.equal(request.level, "console");
    assert.ok(request.attributes["duration.ms"] >= 0);
    assert.equal(requests.find(entry => entry.attributes["http.route"] === "/otel-failure").level, "error");
    assert.equal(records[0].level, "error");
    assert.equal(records[0].attributes["compat.attribute"], "preserved");
  }
  passed = true;
} catch (error) {
  console.error(error);
} finally {
  await sdk.shutdown();
  await Sentry.close(0);
}
if (passed) {
  process.exitCode = 0;
  console.log(`OpenTelemetry ${process.env.OTEL_SDK_VERSION}, enabled=${enabled}: passed`);
}
