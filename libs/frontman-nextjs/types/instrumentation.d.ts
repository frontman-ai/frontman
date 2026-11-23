import type { Attributes, Context, HrTime, Span } from "@opentelemetry/api";
import type { LogRecordProcessor } from "@opentelemetry/sdk-logs";

interface SpanProcessor {
  onStart(span: Span, parentContext: Context): void;
  onEnd(span: {
    name: string;
    startTime: HrTime;
    endTime: HrTime;
    attributes: Attributes;
  }): void;
  forceFlush(): Promise<void>;
  shutdown(): Promise<void>;
}

export function setup(): [LogRecordProcessor, SpanProcessor];
