# OpenTelemetry Integration

Optional OpenTelemetry processors that export logs and spans to OTEL collectors.

## Installation

Install OpenTelemetry peer dependencies:

```bash
npm install @opentelemetry/api @opentelemetry/sdk-logs @opentelemetry/sdk-trace-base
```

## Usage

In Next.js `instrumentation.ts`:

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { frontmanNextjs } from '@ask-the-llm/frontman-nextjs';

export async function register() {
  // Create Frontman OTEL processors (ReScript compiled to JS)
  const { makeLogRecordProcessor, makeSpanProcessor } = frontmanNextjs.OpenTelemetry;

  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
    }),
    spanProcessors: [
      new BatchSpanProcessor(new OTLPTraceExporter()),
      makeSpanProcessor(),  // Add Frontman span processor
    ],
    logRecordProcessors: [
      makeLogRecordProcessor(),  // Add Frontman log processor
    ],
  });

  sdk.start();
}
```

## What Gets Captured

### Via SpanProcessor
- Next.js HTTP requests (method, path, status, duration)
- Route rendering timing
- API route execution
- Filters out `/frontman` internal paths

### Via LogRecordProcessor
- OTEL logger logs (if you use OTEL logger API)
- Stored in Frontman's circular buffer
- Available via `get_logs` tool

## Safety Features

- **Graceful degradation:** Works without OTEL installed
- **No runtime errors:** Processors fail silently if OTEL missing
- **Zero overhead:** When not configured, no OTEL code runs
- **Non-breaking:** Existing logging unaffected

## Architecture

```
User's OTEL SDK
│
├─> FrontmanSpanProcessor (ReScript)
│   └─> LogCapture.addLog()
│       └─> CircularBuffer
│
└─> FrontmanLogRecordProcessor (ReScript)
    └─> LogCapture.addLog()
        └─> CircularBuffer
```

Processors are pure ReScript with minimal FFI bindings to OTEL SDK types.
