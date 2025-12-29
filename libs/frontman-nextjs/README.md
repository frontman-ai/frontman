# @ask-the-llm/frontman-nextjs

Next.js integration for Frontman - provides development tools and observability for Next.js applications.

## Installation

```bash
npm install @ask-the-llm/frontman-nextjs
```

## Quick Start

### 1. Add Middleware

Create or update `middleware.ts` in your Next.js project root:

```typescript
import { createMiddleware } from '@ask-the-llm/frontman-nextjs';
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
import { setup } from '@ask-the-llm/frontman-nextjs/Instrumentation';
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

### Via Console Patching
- `console.log()`, `console.error()`, `console.warn()`, etc.
- Build output (webpack/turbopack compilation messages)
- Uncaught exceptions and unhandled promise rejections

### Via OpenTelemetry Spans
- HTTP requests (`BaseServer.handleRequest`)
- Route rendering (`AppRender.getBodyResult`)
- API route execution (`AppRouteRouteHandlers.runHandler`)
- Request method, path, status code, duration

All captured data is stored in a circular buffer (1024 entries) and accessible through the Frontman UI.

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
Next.js App
│
├─> instrumentation.ts (startup)
│   └─> setup() initializes LogCapture + returns OTEL processors
│       └─> Console patching, error handlers
│
├─> middleware.ts (per-request)
│   └─> Serves Frontman UI at /__frontman
│
└─> OpenTelemetry SDK
    ├─> LogRecordProcessor → LogCapture buffer
    └─> SpanProcessor → LogCapture buffer
```

## Advanced Usage

### Custom OTEL Configuration

If you need more control over OpenTelemetry setup:

```typescript
import { setup } from '@ask-the-llm/frontman-nextjs/Instrumentation';
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
- ✅ Console logs are still captured (via `createMiddleware()`)
- ✅ Build output is tracked
- ✅ Errors are logged
- ✅ Frontman UI available at `/__frontman`
- ❌ HTTP spans are not captured (requires OTEL)

The middleware automatically calls `LogCapture.initialize()`, so console patching happens even without `instrumentation.ts`.

## API

### `createMiddleware(options?)`

Creates a Next.js middleware handler that serves the Frontman UI and handles tool requests.

**Returns:** `(request: NextRequest) => Promise<NextResponse | undefined>`

### `setup()`

Initializes LogCapture (console patching, error handlers) and returns OTEL processors.

**Returns:** `[logRecordProcessor, spanProcessor]`

## License

MIT
