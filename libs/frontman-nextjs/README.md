# @frontman-ai/nextjs

Next.js integration for Frontman - provides development tools and observability for Next.js applications.

## Installation

### Quick Install (Recommended)

The fastest way to install Frontman is using our CLI installer:

```bash
npx @frontman-ai/nextjs install

# Or with a custom server host
npx @frontman-ai/nextjs install --server frontman.company.com
```

The installer will:
- Detect your Next.js version (15 or 16+)
- Create the appropriate middleware/proxy file
- Set up OpenTelemetry instrumentation
- Configure everything to connect to your Frontman server

### CLI Options

```bash
npx @frontman-ai/nextjs install [options]

Options:
  --server <host>   Frontman server host (default: api.frontman.sh)
  --prefix <path>   Target directory (default: current directory)
  --dry-run         Preview changes without writing files
  --skip-deps       Skip dependency installation
  --help            Show help message
```

### Manual Installation

If you prefer to set things up manually or need to integrate with an existing configuration:

```bash
npm install @frontman-ai/nextjs
```

Then follow the [Manual Setup](#manual-setup) instructions below.

## Quick Start

After running the installer, you're ready to go! Start your Next.js dev server:

```bash
npm run dev
```

Then open your browser to `http://localhost:3000/frontman` to access the Frontman UI.

## Manual Setup

### Next.js 15 (middleware.ts)

Create `middleware.ts` in your project root:

```typescript
import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: 'api.frontman.sh', // or 'frontman.local:4000' for local development
});

export async function middleware(req: NextRequest) {
  const response = await frontman(req);
  if (response) return response;
  return NextResponse.next();
}

export const config = {
  matcher: ['/frontman', '/frontman/:path*'],
};
```

### Next.js 16+ (proxy.ts)

Create `proxy.ts` in your project root:

```typescript
import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: 'api.frontman.sh', // or 'frontman.local:4000' for local development
});

export function proxy(req: NextRequest): NextResponse | Promise<NextResponse> {
  if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/')) {
    return frontman(req) || NextResponse.next();
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/frontman', '/frontman/:path*'],
};
```

### OpenTelemetry Setup (Recommended)

Create `instrumentation.ts` in your project root (or `src/` if you use that directory):

```typescript
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { NodeSDK } = await import('@opentelemetry/sdk-node');
    const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
    const [logProcessor, spanProcessor] = setup();
    new NodeSDK({
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }
}
```

**That's it!** Frontman will now:
- Capture console logs, build output, and errors
- Track Next.js HTTP requests, API routes, and rendering
- Make all logs available via the Frontman UI at `/frontman`

## Adding to Existing Files

If you already have `middleware.ts`, `proxy.ts`, or `instrumentation.ts` files, the installer will show you manual integration steps. Here's how to add Frontman to existing files:

### Existing middleware.ts (Next.js 15)

```typescript
import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';
// ... your other imports

const frontman = createMiddleware({
  host: 'api.frontman.sh', // or 'frontman.local:4000' for local development
});

export async function middleware(req: NextRequest) {
  // Add Frontman handler first - it will handle /frontman/* routes
  const response = await frontman(req);
  if (response) return response;

  // ... your existing middleware logic below
  return NextResponse.next();
}

export const config = {
  // Add Frontman matcher alongside your existing matchers
  matcher: ['/frontman', '/frontman/:path*', '/your-other-routes/:path*'],
};
```

### Existing proxy.ts (Next.js 16+)

```typescript
import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';
// ... your other imports

const frontman = createMiddleware({
  host: 'api.frontman.sh', // or 'frontman.local:4000' for local development
});

export function proxy(req: NextRequest): NextResponse | Promise<NextResponse> {
  // Add Frontman handler first - it will handle /frontman/* routes
  if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/')) {
    return frontman(req) || NextResponse.next();
  }

  // ... your existing proxy logic below
  return NextResponse.next();
}

export const config = {
  // Add Frontman matcher alongside your existing matchers
  matcher: ['/frontman', '/frontman/:path*', '/your-other-routes/:path*'],
};
```

### Existing instrumentation.ts

If you **don't have OpenTelemetry** set up yet:

```typescript
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { NodeSDK } = await import('@opentelemetry/sdk-node');
    const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
    const [logProcessor, spanProcessor] = setup();

    new NodeSDK({
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }

  // ... your existing instrumentation logic
}
```

If you **already have OpenTelemetry** set up, add the Frontman processors to your existing configuration:

```typescript
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
    const [logProcessor, spanProcessor] = setup();

    new NodeSDK({
      // ... your existing OTEL config
      logRecordProcessors: [logProcessor, ...yourExistingLogProcessors],
      spanProcessors: [spanProcessor, ...yourExistingSpanProcessors],
    }).start();
  }
}
```

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
  host: string,                // Frontman server host (required) - the client UI connects here via WebSocket
  basePath: string,            // Base path for Frontman routes (default: "frontman")
  serverName: string,          // Server name (default: "frontman-nextjs")
  serverVersion: string,       // Server version (default: package version)
  clientUrl: string,           // Custom client bundle URL
  clientCssUrl: string,        // Custom client CSS URL
  entrypointUrl: string,       // Custom entrypoint URL
  projectRoot: string,         // Project root directory (default: process.cwd())
})
```

### Understanding the `host` Option

The `host` option specifies the Frontman server that the client UI will connect to for AI capabilities. When you visit `/frontman` in your Next.js app:

1. The middleware serves the Frontman UI HTML
2. The UI loads the client JavaScript with `?host=<your-host>` 
3. The client establishes a WebSocket connection to `wss://<host>/socket`
4. AI interactions and tool calls flow through this connection

The middleware itself doesn't connect to the Frontman server - it only passes the host to the client.

**Examples:**
- Production: `host: 'api.frontman.sh'` → client connects to `wss://api.frontman.sh/socket`
- Local dev: `host: 'frontman.local:4000'` → client connects to `wss://frontman.local:4000/socket`

## Supported Next.js Versions

| Version | Middleware File | Status |
|---------|----------------|--------|
| Next.js 15.x | `middleware.ts` | Fully supported |
| Next.js 16.x | `proxy.ts` | Fully supported |

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
├─> middleware.ts / proxy.ts (per-request)
│   └─> Serves Frontman UI at /frontman
│       └─> Connects to Frontman server for AI tools
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
import { setup } from '@frontman-ai/nextjs/Instrumentation';
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
- Console logs are still captured (auto-initialized at module import)
- Build output is tracked
- Errors are logged
- Frontman UI available at `/frontman`
- HTTP spans are not captured (requires OTEL)

LogCapture auto-initializes when the module is imported, so console patching happens automatically in Node.js environments - no explicit initialization needed.

### Custom LogCapture Configuration

You can customize the buffer size and stdout patterns:

```typescript
import { initialize } from '@frontman-ai/nextjs/LogCapture';

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
- You have `instrumentation.ts` that imports from `@frontman-ai/nextjs/Instrumentation`
- OR you have `middleware.ts` that imports from `@frontman-ai/nextjs`

**Check 2: Verify Node.js runtime**
LogCapture doesn't run in browser or Edge runtime. Check your environment:
```javascript
console.log('Runtime:', process.env.NEXT_RUNTIME); // Should be 'nodejs'
```

**Check 3: Verify buffer contents**
Query the buffer directly to see if logs are present:
```typescript
import { getLogs } from '@frontman-ai/nextjs/LogCapture';

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

### Installer shows "manual modification required"

This happens when you have existing middleware, proxy, or instrumentation files that don't already include Frontman. The installer won't overwrite your existing code. Follow the [Adding to Existing Files](#adding-to-existing-files) instructions to manually integrate Frontman.

## API

### `createMiddleware(options)`

Creates a Next.js middleware handler that serves the Frontman UI and connects to your Frontman server.

```typescript
import { createMiddleware } from '@frontman-ai/nextjs';

const middleware = createMiddleware({
  host: string,                // Frontman server host (required)
  basePath: string,            // Base path (default: "frontman")
  serverName: string,          // Server name (default: "frontman-nextjs")
  serverVersion: string,       // Version (default: package version)
  projectRoot: string,         // Project root (default: process.cwd())
});
```

**Returns:** `(request: NextRequest) => Promise<NextResponse | undefined>`

### `setup()`

Initializes LogCapture (console patching, error handlers) and returns OTEL processors for use with OpenTelemetry SDK.

```typescript
import { setup } from '@frontman-ai/nextjs/Instrumentation';

const [logProcessor, spanProcessor] = setup();
```

**Returns:** `[LogRecordProcessor, SpanProcessor]`

### `initialize(config?)`

Manually initialize LogCapture with custom configuration. Usually not needed since auto-initialization happens at module import.

```typescript
import { initialize } from '@frontman-ai/nextjs/LogCapture';

initialize({
  bufferCapacity: number,           // Buffer size (default: 1024)
  stdoutPatterns: string[],         // Patterns to capture from stdout
});
```

**Returns:** `void`

### `getLogs(options?)`

Query the log buffer with optional filters.

```typescript
import { getLogs } from '@frontman-ai/nextjs/LogCapture';

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
