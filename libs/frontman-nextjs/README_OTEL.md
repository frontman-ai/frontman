# OpenTelemetry Integration

Optional OpenTelemetry processors that capture logs and spans into Frontman's circular buffer, making them available via the `get_logs` tool and Frontman UI.

## Installation

Install OpenTelemetry peer dependencies:

```bash
npm install @opentelemetry/sdk-node @opentelemetry/sdk-trace-base @opentelemetry/sdk-logs
```

## Quick Start

In Next.js `instrumentation.ts`:

```typescript
import { setup } from '@frontman-ai/nextjs/Instrumentation';
import { NodeSDK } from '@opentelemetry/sdk-node';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // setup() initializes LogCapture and returns OTEL processors
    const [logProcessor, spanProcessor] = setup();

    new NodeSDK({
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }
}
```

That's it! Frontman processors will now capture OTEL logs and spans into the same buffer as console logs.

## Advanced Usage

If you need to export to external OTEL collectors AND capture in Frontman:

```typescript
import { setup } from '@frontman-ai/nextjs/Instrumentation';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const [logProcessor, spanProcessor] = setup();

    new NodeSDK({
      // Export to external collector
      traceExporter: new OTLPTraceExporter({
        url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
      }),
      spanProcessors: [
        // Export spans to external collector
        new BatchSpanProcessor(new OTLPTraceExporter()),
        // AND capture spans in Frontman buffer
        spanProcessor,
      ],
      logRecordProcessors: [
        // Capture OTEL logs in Frontman buffer
        logProcessor,
      ],
    }).start();
  }
}
```

## What Gets Captured

### Via SpanProcessor (`FrontmanNextjs__SpanProcessor`)
Captures Next.js request/response spans from the OpenTelemetry instrumentation:

**Captured spans:**
- `BaseServer.handleRequest` - HTTP requests with method, path, status code
- `AppRender.getBodyResult` - Route rendering timing
- `AppRouteRouteHandlers.runHandler` - API route execution
- Duration, status, and other span attributes

**Filtering:**
- Automatically filters out `/frontman` internal paths
- Converts OTEL spans to log entries with level: `console`
- Stores in the same circular buffer as console logs

**Log entry format:**
```typescript
{
  timestamp: "2025-01-15T12:34:56.789Z",
  level: "console",
  message: "GET /api/users → 200 (45ms)",
  attributes: {
    "http.method": "GET",
    "http.route": "/api/users",
    "http.status_code": 200,
  },
  resource: undefined,
  consoleMethod: undefined,
}
```

### Via LogRecordProcessor (`FrontmanNextjs__LogRecordProcessor`)
Captures logs from the OTEL Logger API (if you use it):

```typescript
import { logs } from '@opentelemetry/api-logs';

const logger = logs.getLogger('my-app');
logger.emit({
  severityText: 'INFO',
  body: 'User logged in',
  attributes: { userId: '123' },
});
```

These logs are converted to Frontman log entries and stored in the buffer alongside console logs.

## How It Works

### Initialization Flow

1. **Module import** → LogCapture auto-initializes and creates `globalThis.__FRONTMAN_INSTANCE__`
2. **`setup()` called** → Returns pre-configured OTEL processors
3. **OTEL SDK started** → Processors receive spans and log records
4. **Processors write to buffer** → Same buffer used by console patching
5. **`get_logs` tool queries buffer** → All logs available via Frontman UI

### Data Flow

```
OTEL SDK
│
├─> Span emitted (e.g., HTTP request)
│   └─> FrontmanSpanProcessor.onEnd()
│       └─> Converts span to log message
│           └─> LogCapture.addLog(level: "console", message: "GET /api ...")
│               └─> globalThis.__FRONTMAN_INSTANCE__.buffer
│
└─> LogRecord emitted (e.g., logger.emit())
    └─> FrontmanLogRecordProcessor.onEmit()
        └─> Converts log record to log entry
            └─> LogCapture.addLog(level: "console", message: "...")
                └─> globalThis.__FRONTMAN_INSTANCE__.buffer
```

### Cross-Context Sharing

The OTEL processors write to the same `globalThis.__FRONTMAN_INSTANCE__` buffer as console logs, ensuring all logs from all sources (console, stdout, OTEL) are unified in one queryable buffer.

## Implementation Details

### ReScript Architecture

Both processors are implemented in pure ReScript:

**Files:**
- `FrontmanNextjs__SpanProcessor.res` - Implements OTEL `SpanProcessor` interface
- `FrontmanNextjs__LogRecordProcessor.res` - Implements OTEL `LogRecordProcessor` interface
- `FrontmanNextjs__OpenTelemetry__Integration.res` - Provides FFI bindings to OTEL SDK types

**Type Safety:**
- Minimal FFI - only what's needed to interface with OTEL SDK
- ReScript's type system ensures correct processor implementation
- No runtime type errors

### Performance Considerations

- **Synchronous processing:** Both processors use `onEnd`/`onEmit` (not async) for minimal overhead
- **No batching:** Logs immediately written to circular buffer
- **Fixed buffer:** O(1) writes, automatic eviction of oldest entries
- **Shared buffer:** No duplication across contexts

## Safety Features

- **Graceful degradation:** Works without OTEL installed
- **No runtime errors:** Processors fail silently if OTEL types missing
- **Zero overhead:** When not configured, no OTEL code runs
- **Non-breaking:** Existing logging unaffected
- **Type-safe:** ReScript compilation catches errors at build time
