# @frontman/frontman-nextjs

Next.js integration for Frontman - provides development tools and observability for Next.js applications.

## Installation

```bash
npm install @frontman/frontman-nextjs
```

## Quick Start

### 1. Add Middleware

Create or update `middleware.ts` in your Next.js project root:

```typescript
import { createMiddleware } from '@frontman/frontman-nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  isDev: process.env.NODE_ENV === 'development',
});

export async function middleware(req: NextRequest) {
  const response = await frontman(req);
  if (response) return response;
  return NextResponse.next();
}

export const config = {
  matcher: ['/__frontman/:path*'],
};
```

### 2. Enable OpenTelemetry (Recommended)

Install OpenTelemetry dependencies:

```bash
npm install @opentelemetry/sdk-node @opentelemetry/sdk-trace-base @opentelemetry/sdk-logs
```

Create `instrumentation.ts` in your project root:

```typescript
import { setup } from '@frontman/frontman-nextjs/Instrumentation';
import { NodeSDK } from '@opentelemetry/sdk-node';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const [logProcessor, spanProcessor] = setup();
    new NodeSDK({
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }
}
```

**That's it!** Frontman will now:
- ✅ Capture console logs, build output, and errors
- ✅ Track Next.js HTTP requests, API routes, and rendering
- ✅ Make all logs available via the Frontman UI at `/__frontman`

## What Gets Captured

### Automatic Console Patching (Node.js only)
LogCapture automatically initializes when the module is imported and patches:
- All console methods: `console.log()`, `console.error()`, `console.warn()`, `console.info()`, `console.debug()`
- `process.stdout.write()` for build output (webpack/turbopack compilation messages)
- `process.on('uncaughtException')` for unhandled errors
- `process.on('unhandledRejection')` for unhandled promise rejections

**Browser environments are automatically skipped** - no console patching occurs in the browser.

### Via OpenTelemetry Spans (Optional)
When you set up `instrumentation.ts`:
- HTTP requests (`BaseServer.handleRequest`)
- Route rendering (`AppRender.getBodyResult`)
- API route execution (`AppRouteRouteHandlers.runHandler`)
- Request method, path, status code, duration

### Storage & Cross-Context Sharing
All captured data is stored in a **circular buffer** (1024 entries by default) using a `globalThis` singleton pattern. This ensures logs are shared across Next.js/Turbopack execution contexts:
- Instrumentation context (startup)
- Page render context
- API route context
- Middleware context (Edge runtime - read-only)

The buffer persists for the lifetime of the Node.js process and is accessible through the Frontman UI and `get_logs` tool.

## Configuration Options

### Middleware Options

```typescript
createMiddleware({
  isDev: boolean,              // Enable dev features (default: false)
  basePath: string,            // Base path for Frontman routes (default: "__frontman")
  serverName: string,          // Server name (default: "frontman-nextjs")
  serverVersion: string,       // Server version (default: package version)
  clientUrl: string,           // Custom client bundle URL
  clientCssUrl: string,        // Custom client CSS URL
  entrypointUrl: string,       // Custom entrypoint URL
  isLightTheme: boolean,       // Use light theme (default: false)
  projectRoot: string,         // Project root directory (default: process.cwd())
})
```

## Supported Next.js Versions

- Next.js 15+ (instrumentation.ts stable)
- Next.js 16+ (latest)

Both versions have built-in OpenTelemetry support with no additional configuration required.

## Architecture

```
Next.js App (Turbopack/Webpack)
│
├─> Module Import (first context - instrumentation)
│   └─> LogCapture auto-initializes at module level
│       ├─> Creates globalThis.__FRONTMAN_INSTANCE__
│       ├─> Patches console.log/warn/error/info/debug
│       ├─> Intercepts process.stdout.write
│       └─> Listens to uncaughtException/unhandledRejection
│
├─> Module Import (second context - page render)
│   └─> LogCapture reuses existing globalThis.__FRONTMAN_INSTANCE__
│       └─> Same buffer, no re-patching (guarded by __FRONTMAN_CONSOLE_PATCHED__ flag)
│
├─> instrumentation.ts (startup) - OPTIONAL
│   └─> setup() returns OTEL processors that write to same buffer
│
├─> middleware.ts (per-request)
│   └─> Serves Frontman UI at /__frontman
│       └─> get_logs tool queries the shared buffer
│
└─> OpenTelemetry SDK (optional)
    ├─> LogRecordProcessor → globalThis.__FRONTMAN_INSTANCE__.buffer
    └─> SpanProcessor → globalThis.__FRONTMAN_INSTANCE__.buffer
```

### Key Technical Details

**Cross-Context Buffer Sharing**
- Next.js 15+ with Turbopack runs code in multiple isolated contexts
- `globalThis.__FRONTMAN_INSTANCE__` stores the singleton buffer instance
- All contexts read/write to the same circular buffer
- Console patching happens only once (protected by `__FRONTMAN_CONSOLE_PATCHED__` flag)

**Circular Buffer**
- Fixed capacity: 1024 entries (configurable)
- Oldest entries automatically evicted when full
- Entries include: timestamp, level, message, attributes, consoleMethod
- Thread-safe for concurrent writes from different contexts

## Advanced Usage

### Custom OTEL Configuration

If you need more control over OpenTelemetry setup:

```typescript
import { setup } from '@frontman/frontman-nextjs/Instrumentation';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const [logProcessor, spanProcessor] = setup();

    new NodeSDK({
      serviceName: 'my-app',
      resource: resourceFromAttributes({
        'service.version': '1.0.0',
      }),
      traceExporter: new OTLPTraceExporter({
        url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
      }),
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }
}
```

### Without OpenTelemetry

Frontman works without OpenTelemetry! If you only set up middleware (skip `instrumentation.ts`):
- ✅ Console logs are still captured (auto-initialized at module import)
- ✅ Build output is tracked
- ✅ Errors are logged
- ✅ Frontman UI available at `/__frontman`
- ❌ HTTP spans are not captured (requires OTEL)

LogCapture auto-initializes when the module is imported, so console patching happens automatically in Node.js environments - no explicit initialization needed.

### Custom LogCapture Configuration

You can customize the buffer size and stdout patterns:

```typescript
import { initialize } from '@frontman/frontman-nextjs/LogCapture';

// Call this BEFORE any console.log() calls (e.g., in instrumentation.ts)
initialize({
  bufferCapacity: 2048,  // Default: 1024
  stdoutPatterns: ['webpack', 'turbopack', 'Compiled', 'Failed', 'custom-pattern'],
});
```

**Note:** Configuration only takes effect on the first call. Subsequent calls are ignored because the singleton instance is already created.

## Troubleshooting

### Logs not being captured

**Check 1: Verify module is imported**
LogCapture only initializes when the module is imported in a Node.js context. Make sure either:
- You have `instrumentation.ts` that imports from `@frontman/frontman-nextjs/Instrumentation`
- OR you have `middleware.ts` that imports from `@frontman/frontman-nextjs`

**Check 2: Verify Node.js runtime**
LogCapture doesn't run in browser or Edge runtime. Check your environment:
```javascript
console.log('Runtime:', process.env.NEXT_RUNTIME); // Should be 'nodejs'
```

**Check 3: Verify buffer contents**
Query the buffer directly to see if logs are present:
```typescript
import { getLogs } from '@frontman/frontman-nextjs/LogCapture';

const allLogs = getLogs();
console.log('Buffer contains', allLogs.length, 'logs');
```

**Check 4: Multiple contexts**
In Next.js 15+, code may run in different contexts. Verify all contexts share the same buffer:
```javascript
console.log('Instance:', globalThis.__FRONTMAN_INSTANCE__);
console.log('Buffer size:', globalThis.__FRONTMAN_INSTANCE__?.buffer.contents.items.length);
```

### Console logs appear twice

This is normal behavior - LogCapture captures logs AND calls the original console method so logs still appear in your terminal/browser console.

### Build output not captured

By default, only these patterns are captured from `process.stdout`:
- "webpack"
- "turbopack"
- "Compiled"
- "Failed"

To capture additional patterns, use custom configuration (see above).

## API

### `createMiddleware(options?)`

Creates a Next.js middleware handler that serves the Frontman UI and handles tool requests.

```typescript
import { createMiddleware } from '@frontman/frontman-nextjs';

const middleware = createMiddleware({
  isDev: boolean,              // Enable dev features (default: false)
  basePath: string,            // Base path (default: "__frontman")
  serverName: string,          // Server name (default: "frontman-nextjs")
  serverVersion: string,       // Version (default: package version)
  projectRoot: string,         // Project root (default: process.cwd())
});
```

**Returns:** `(request: NextRequest) => Promise<NextResponse | undefined>`

### `setup()`

Initializes LogCapture (console patching, error handlers) and returns OTEL processors for use with OpenTelemetry SDK.

```typescript
import { setup } from '@frontman/frontman-nextjs/Instrumentation';

const [logProcessor, spanProcessor] = setup();
```

**Returns:** `[LogRecordProcessor, SpanProcessor]`

### `initialize(config?)`

Manually initialize LogCapture with custom configuration. Usually not needed since auto-initialization happens at module import.

```typescript
import { initialize } from '@frontman/frontman-nextjs/LogCapture';

initialize({
  bufferCapacity: number,           // Buffer size (default: 1024)
  stdoutPatterns: string[],         // Patterns to capture from stdout
});
```

**Returns:** `void`

### `getLogs(options?)`

Query the log buffer with optional filters.

```typescript
import { getLogs } from '@frontman/frontman-nextjs/LogCapture';

const logs = getLogs({
  pattern: string,        // Regex pattern to match messages (case-insensitive)
  level: 'console' | 'build' | 'error',  // Filter by log level
  since: number,          // Unix timestamp - only logs after this time
  tail: number,           // Limit to last N logs
});
```

**Returns:** `LogEntry[]`

**LogEntry type:**
```typescript
type LogEntry = {
  timestamp: string;                           // ISO 8601 timestamp
  level: 'console' | 'build' | 'error';       // Log level
  message: string;                             // Log message (ANSI codes stripped)
  attributes?: Record<string, any>;            // Additional attributes
  resource?: Record<string, any>;              // Resource info
  consoleMethod?: 'log' | 'info' | 'warn' | 'error' | 'debug';  // Original console method
};
```

## License

MIT
