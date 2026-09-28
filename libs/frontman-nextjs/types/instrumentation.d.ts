import type { LogRecordProcessor } from "@opentelemetry/sdk-logs";
import type { SpanProcessor } from "@opentelemetry/sdk-trace-base";

export function setup(): [LogRecordProcessor, SpanProcessor];
