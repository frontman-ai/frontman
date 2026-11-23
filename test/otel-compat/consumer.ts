import { setup } from "@frontman-ai/nextjs/Instrumentation";
import type { LogRecordProcessor } from "@opentelemetry/sdk-logs";
import type { SpanProcessor } from "@opentelemetry/sdk-trace-base";
import { NodeSDK } from "@opentelemetry/sdk-node";

const [logProcessor, spanProcessor]: [LogRecordProcessor, SpanProcessor] = setup();
new NodeSDK({ spanProcessors: [spanProcessor], logRecordProcessors: [logProcessor] });
