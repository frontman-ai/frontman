# OpenTelemetry Integration Plan - ReScript Implementation

## Overview
Add OpenTelemetry (OTEL) support to frontman-nextjs using **pure ReScript** with minimal FFI, aligned with Tidewave's architecture. Must be **safe, opt-in, and non-breaking**.

## Current State

### Frontman-nextjs Logger
- Pure ReScript implementation
- Circular buffer (1024 entries)
- Captures: console logs, build output, uncaught errors
- Log structure: `{timestamp, level, message, attributes?, resource?, consoleMethod?}`

### Tidewave Logger (Reference)
- TypeScript with OTEL processors
- Same circular buffer pattern
- `TidewaveSpanProcessor` captures Next.js HTTP spans
- `TidewaveLogRecordProcessor` captures OTEL log records
- Auto-patches console on module import

## Design Goals

1. **Non-Breaking:** Existing functionality unchanged
2. **Opt-In:** OTEL dependencies optional (peer dependencies)
3. **Safe:** Graceful degradation if OTEL unavailable
4. **Performance:** Zero overhead when not configured
5. **ReScript-First:** Pure ReScript with minimal FFI
6. **Tidewave-Aligned:** Match Tidewave's architecture

## Implementation Plan

### Phase 1: Add OTEL Peer Dependencies

**File:** `libs/frontman-nextjs/package.json`

```json
{
  "peerDependencies": {
    "@opentelemetry/api": "^1.9.0",
    "@opentelemetry/sdk-logs": "^0.52.0",
    "@opentelemetry/sdk-trace-base": "^1.25.0"
  },
  "peerDependenciesMeta": {
    "@opentelemetry/api": { "optional": true },
    "@opentelemetry/sdk-logs": { "optional": true },
    "@opentelemetry/sdk-trace-base": { "optional": true }
  }
}
```

**Why peer dependencies?**
- User installs only if needed
- No impact on existing users
- Prevents version conflicts

### Phase 2: Create OTEL Bindings

**File:** `libs/frontman-nextjs/src/FrontmanNextjs__OpenTelemetry__Bindings.res`

Minimal ReScript bindings for OTEL SDK:

```rescript
// High-resolution time: [seconds, nanoseconds]
type hrTime = (float, float)

// Span/log context
type context

// Attributes dictionary
type attributes = Dict.t<JSON.t>

// === SDK Logs Bindings ===

module Logs = {
  // SDK log record
  type sdkLogRecord
  @get external hrTime: sdkLogRecord => hrTime = "hrTime"
  @get @return(nullable) external body: sdkLogRecord => option<string> = "body"
  @get @return(nullable) external severityText: sdkLogRecord => option<string> = "severityText"
  @get @return(nullable) external attributes: sdkLogRecord => option<attributes> = "attributes"
  @get @return(nullable) external resource: sdkLogRecord => option<resource> = "resource"

  and resource
  @get @return(nullable) external resourceAttributes: resource => option<attributes> = "attributes"

  // LogRecordProcessor interface (what user passes to OTEL SDK)
  type logRecordProcessor = {
    "onEmit": (. sdkLogRecord, option<context>) => unit,
    "forceFlush": (. unit) => promise<unit>,
    "shutdown": (. unit) => promise<unit>,
  }

  @new external makeProcessor: {..} => logRecordProcessor = "Object"
}

// === SDK Trace Bindings ===

module Trace = {
  // Readable span (completed)
  type readableSpan
  @get external name: readableSpan => string = "name"
  @get external kind: readableSpan => int = "kind"
  @get external startTime: readableSpan => hrTime = "startTime"
  @get external endTime: readableSpan => hrTime = "endTime"
  @get external attributes: readableSpan => attributes = "attributes"

  // Regular span (in-flight)
  type span

  // SpanProcessor interface
  type spanProcessor = {
    "onStart": (. span, context) => unit,
    "onEnd": (. readableSpan) => unit,
    "forceFlush": (. unit) => promise<unit>,
    "shutdown": (. unit) => promise<unit>,
  }

  @new external makeProcessor: {..} => spanProcessor = "Object"
}
```

### Phase 3: Port LogRecordProcessor

**File:** `libs/frontman-nextjs/src/FrontmanNextjs__LogRecordProcessor.res`

```rescript
open FrontmanNextjs__OpenTelemetry__Bindings

// Convert OTEL severity to our logLevel
let mapSeverity = (severityText: option<string>): LogCapture.logLevel => {
  switch severityText {
  | Some("ERROR") | Some("FATAL") | Some("CRITICAL") => LogCapture.Error
  | Some("WARN") | Some("WARNING") => LogCapture.Console
  | _ => LogCapture.Console
  }
}

// Convert hrTime to ISO timestamp
let hrTimeToISO = ((seconds, nanos): hrTime): string => {
  let ms = seconds *. 1000.0 +. nanos /. 1_000_000.0
  ms->Date.fromTime->Date.toISOString
}

let make = (): Logs.logRecordProcessor => {
  let onEmit = (. logRecord: Logs.sdkLogRecord, _context: option<context>): unit => {
    try {
      let body = logRecord->Logs.body->Option.getOr("")
      let timestamp = logRecord->Logs.hrTime->hrTimeToISO
      let level = logRecord->Logs.severityText->mapSeverity

      // Convert OTEL attributes to JSON
      let attributes = logRecord
        ->Logs.attributes
        ->Option.map(attrs => attrs->JSON.Encode.object)

      // Add to LogCapture
      let state = LogCapture.getInstance()
      LogCapture.addLog(state, level, body, ~attributes?)
    } catch {
    | _ => () // Silently fail - don't break logging
    }
  }

  let forceFlush = (. ()): promise<unit> => Promise.resolve()
  let shutdown = (. ()): promise<unit> => Promise.resolve()

  Logs.makeProcessor({
    "onEmit": onEmit,
    "forceFlush": forceFlush,
    "shutdown": shutdown,
  })
}
```

### Phase 4: Port SpanProcessor

**File:** `libs/frontman-nextjs/src/FrontmanNextjs__SpanProcessor.res`

```rescript
open FrontmanNextjs__OpenTelemetry__Bindings

// Calculate span duration in ms
let calculateDuration = (span: Trace.readableSpan): float => {
  let (startSec, startNano) = span->Trace.startTime
  let (endSec, endNano) = span->Trace.endTime
  let startMs = startSec *. 1000.0 +. startNano /. 1_000_000.0
  let endMs = endSec *. 1000.0 +. endNano /. 1_000_000.0
  endMs -. startMs
}

// Get string attribute
let getStr = (attrs: attributes, key: string): option<string> => {
  attrs->Dict.get(key)->Option.flatMap(JSON.Decode.string)
}

// Get number attribute
let getNum = (attrs: attributes, key: string): option<float> => {
  attrs->Dict.get(key)->Option.flatMap(JSON.Decode.float)
}

let make = (): Trace.spanProcessor => {
  let onStart = (. _span: Trace.span, _ctx: context): unit => ()

  let onEnd = (. span: Trace.readableSpan): unit => {
    try {
      let attrs = span->Trace.attributes
      let spanType = getStr(attrs, "next.span_type")

      // Filter: only relevant Next.js spans (from Tidewave)
      let relevantTypes = [
        "BaseServer.handleRequest",
        "AppRender.getBodyResult",
        "AppRouteRouteHandlers.runHandler",
      ]

      let isRelevant = spanType->Option.mapOr(false, st =>
        relevantTypes->Array.includes(st)
      )

      if isRelevant {
        let httpMethod = getStr(attrs, "http.method")
        let route = getStr(attrs, "next.route")->Option.or(getStr(attrs, "http.route"))
        let statusCode = getNum(attrs, "http.status_code")
        let path = route->Option.getOr("unknown")

        // Filter out /frontman paths (like Tidewave filters /tidewave)
        if !path->String.startsWith("/frontman") {
          let durationMs = calculateDuration(span)

          // Build message and level based on span type
          let (message, level) = switch spanType {
          | Some("BaseServer.handleRequest") => {
              let method = httpMethod->Option.getOr("UNKNOWN")
              let status = statusCode->Option.map(Float.toString)->Option.getOr("unknown")
              let msg = `${method} ${path} ${status} ${durationMs->Float.toFixed(~digits=2)}ms`
              let lvl = statusCode->Option.mapOr(LogCapture.Console, code =>
                code >= 500.0 ? LogCapture.Error : LogCapture.Console
              )
              (msg, lvl)
            }
          | Some("AppRender.getBodyResult") => {
              let msg = `Rendered route: ${path} (${durationMs->Float.toFixed(~digits=2)}ms)`
              (msg, LogCapture.Console)
            }
          | Some("AppRouteRouteHandlers.runHandler") => {
              let msg = `API route: ${path} (${durationMs->Float.toFixed(~digits=2)}ms)`
              (msg, LogCapture.Console)
            }
          | _ => ("", LogCapture.Console)
          }

          if message != "" {
            // Build attributes
            let logAttrs = Dict.fromArray([
              ("log.origin", "opentelemetry-span"->JSON.Encode.string),
              ("span.name", span->Trace.name->JSON.Encode.string),
              ("span.type", spanType->Option.getOr("")->JSON.Encode.string),
              ("http.method", httpMethod->Option.getOr("")->JSON.Encode.string),
              ("http.route", route->Option.getOr("")->JSON.Encode.string),
              ("http.status_code", statusCode->Option.map(JSON.Encode.float)->Option.getOr(JSON.Encode.null)),
              ("duration.ms", durationMs->JSON.Encode.float),
            ])->JSON.Encode.object

            // Convert timestamp
            let (endSec, endNano) = span->Trace.endTime
            let timestamp = (endSec, endNano)->hrTimeToISO

            // Add to LogCapture
            let state = LogCapture.getInstance()
            LogCapture.addLog(state, level, message, ~attributes=logAttrs)
          }
        }
      }
    } catch {
    | _ => () // Silently fail
    }
  }

  let forceFlush = (. ()): promise<unit> => Promise.resolve()
  let shutdown = (. ()): promise<unit> => Promise.resolve()

  Trace.makeProcessor({
    "onStart": onStart,
    "onEnd": onEnd,
    "forceFlush": forceFlush,
    "shutdown": shutdown,
  })
}

// Helper function (shared with LogRecordProcessor)
let hrTimeToISO = ((seconds, nanos): hrTime): string => {
  let ms = seconds *. 1000.0 +. nanos /. 1_000_000.0
  ms->Date.fromTime->Date.toISOString
}
```

### Phase 5: Export OpenTelemetry Module

**File:** `libs/frontman-nextjs/src/FrontmanNextjs__OpenTelemetry.res`

```rescript
// OpenTelemetry integration for Frontman
// Opt-in: requires user to install @opentelemetry/* packages

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings

// Processor factories (return OTEL processor objects)
let makeLogRecordProcessor = FrontmanNextjs__LogRecordProcessor.make
let makeSpanProcessor = FrontmanNextjs__SpanProcessor.make

// Convenience: create both at once
let makeProcessors = () => (
  makeLogRecordProcessor(),
  makeSpanProcessor(),
)
```

**Update:** `libs/frontman-nextjs/src/FrontmanNextjs.res`

```rescript
// ... existing exports ...

// OpenTelemetry (optional - requires peer dependencies)
module OpenTelemetry = FrontmanNextjs__OpenTelemetry
```

### Phase 6: Documentation

**File:** `libs/frontman-nextjs/README_OTEL.md`

````markdown
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
````

## Files to Create/Modify

**New Files:**
- `libs/frontman-nextjs/src/FrontmanNextjs__OpenTelemetry__Bindings.res` - OTEL SDK bindings
- `libs/frontman-nextjs/src/FrontmanNextjs__LogRecordProcessor.res` - Log processor
- `libs/frontman-nextjs/src/FrontmanNextjs__SpanProcessor.res` - Span processor
- `libs/frontman-nextjs/src/FrontmanNextjs__OpenTelemetry.res` - Public API
- `libs/frontman-nextjs/README_OTEL.md` - Usage documentation

**Modified Files:**
- `libs/frontman-nextjs/src/FrontmanNextjs.res` - Export OpenTelemetry module
- `libs/frontman-nextjs/package.json` - Add peer dependencies
- `libs/frontman-nextjs/README.md` - Mention OTEL support

## Comprehensive Testing Strategy

Following the established testing patterns in the codebase (Vitest, describe/test structure, comprehensive coverage).

### Unit Tests - SpanProcessor

**File:** `libs/frontman-nextjs/test/FrontmanNextjs__SpanProcessor.test.res`

```rescript
open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module SpanProcessor = FrontmanNextjs__SpanProcessor
module LogCapture = FrontmanNextjs__LogCapture

// Initialize LogCapture before tests
beforeAll(_t => {
  LogCapture.initialize()
})

describe("SpanProcessor", _t => {
  describe("Processor Creation", _t => {
    test("makeprocessor returns valid processor object", t => {
      let processor = SpanProcessor.make()

      // Should have required methods
      t->expect(processor["onStart"])->Expect.toBeDefined
      t->expect(processor["onEnd"])->Expect.toBeDefined
      t->expect(processor["forceFlush"])->Expect.toBeDefined
      t->expect(processor["shutdown"])->Expect.toBeDefined
    })
  })

  describe("Span Filtering", _t => {
    test("only processes relevant span types", t => {
      let processor = SpanProcessor.make()

      // Mock span with irrelevant type
      let span = %raw(`{
        name: "SomeOtherSpan",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "SomeOtherType"
        }
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length

      processor["onEnd"](. span)

      let afterCount = LogCapture.getLogs()->Array.length

      // Should not add log
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })

    test("processes BaseServer.handleRequest spans", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "GET /api/test",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 500_000_000],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/api/test",
          "http.status_code": 200
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="GET /api/test")
      let found = logs->Array.some(log =>
        log.message->String.includes("GET") &&
        log.message->String.includes("/api/test") &&
        log.message->String.includes("200")
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("processes AppRender.getBodyResult spans", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "render /about",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1000, 250_000_000],
        attributes: {
          "next.span_type": "AppRender.getBodyResult",
          "next.route": "/about"
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="Rendered route")
      let found = logs->Array.some(log =>
        log.message->String.includes("Rendered route: /about")
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("processes AppRouteRouteHandlers.runHandler spans", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "API handler",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1000, 100_000_000],
        attributes: {
          "next.span_type": "AppRouteRouteHandlers.runHandler",
          "next.route": "/api/users"
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="API route")
      let found = logs->Array.some(log =>
        log.message->String.includes("API route: /api/users")
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("filters out /frontman paths", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "GET /frontman/logs",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/frontman/logs"
        }
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length
      processor["onEnd"](. span)
      let afterCount = LogCapture.getLogs()->Array.length

      // Should not add log for /frontman paths
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })
  })

  describe("Duration Calculation", _t => {
    test("calculates duration correctly in milliseconds", t => {
      let processor = SpanProcessor.make()

      // 1.5 second span
      let span = %raw(`{
        name: "slow request",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 500_000_000],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/slow"
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/slow")
      let found = logs->Array.some(log =>
        log.message->String.includes("1500.00ms")
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("handles sub-millisecond durations", t => {
      let processor = SpanProcessor.make()

      // 0.5ms span
      let span = %raw(`{
        name: "fast request",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1000, 500_000],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/fast"
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/fast")
      let found = logs->Array.some(log =>
        log.message->String.includes("0.50ms")
      )

      t->expect(found)->Expect.toBe(true)
    })
  })

  describe("Log Level Mapping", _t => {
    test("maps 5xx status codes to Error level", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "error request",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "POST",
          "http.route": "/api/fail",
          "http.status_code": 500
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/api/fail")
      let errorLogs = logs->Array.filter(log =>
        log.level == Error && log.message->String.includes("/api/fail")
      )

      t->expect(errorLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps 4xx status codes to Console level", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "not found",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/api/notfound",
          "http.status_code": 404
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/api/notfound")
      let consoleLogs = logs->Array.filter(log =>
        log.level == Console && log.message->String.includes("/api/notfound")
      )

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps 2xx status codes to Console level", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "success",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "POST",
          "http.route": "/api/success",
          "http.status_code": 201
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/api/success")
      let consoleLogs = logs->Array.filter(log =>
        log.level == Console && log.message->String.includes("/api/success")
      )

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })
  })

  describe("Attributes Storage", _t => {
    test("stores span metadata in log attributes", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "test span",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.method": "GET",
          "http.route": "/test-attrs",
          "http.status_code": 200
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/test-attrs")
      let logWithAttrs = logs->Array.find(log =>
        log.message->String.includes("/test-attrs")
      )

      switch logWithAttrs {
      | Some(log) => {
          // Should have attributes set
          t->expect(log.attributes->Option.isSome)->Expect.toBe(true)

          // Check for expected attribute keys via JSON encoding
          switch log.attributes {
          | Some(attrs) => {
              let attrsStr = attrs->JSON.stringify
              t->expect(attrsStr->String.includes("log.origin"))->Expect.toBe(true)
              t->expect(attrsStr->String.includes("span.name"))->Expect.toBe(true)
              t->expect(attrsStr->String.includes("duration.ms"))->Expect.toBe(true)
            }
          | None => t->expect(false)->Expect.toBe(true) // Should have attrs
          }
        }
      | None => t->expect(false)->Expect.toBe(true) // Should find log
      }
    })
  })

  describe("Error Handling", _t => {
    test("handles malformed span gracefully", t => {
      let processor = SpanProcessor.make()

      // Span with missing required fields
      let badSpan = %raw(`{
        name: "bad span"
        // Missing startTime, endTime, attributes
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length

      // Should not crash
      processor["onEnd"](. badSpan)

      let afterCount = LogCapture.getLogs()->Array.length

      // Should not add log (silently fails)
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })

    test("handles missing http.method gracefully", t => {
      let processor = SpanProcessor.make()

      let span = %raw(`{
        name: "no method",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "BaseServer.handleRequest",
          "http.route": "/test"
        }
      }`)

      processor["onEnd"](. span)

      let logs = LogCapture.getLogs(~pattern="/test")
      let found = logs->Array.some(log =>
        log.message->String.includes("UNKNOWN /test")
      )

      t->expect(found)->Expect.toBe(true)
    })
  })

  describe("Async Methods", _t => {
    testAsync("forceFlush resolves successfully", async t => {
      let processor = SpanProcessor.make()
      let result = await processor["forceFlush"](.)
      t->expect(result)->Expect.toBe(())
    })

    testAsync("shutdown resolves successfully", async t => {
      let processor = SpanProcessor.make()
      let result = await processor["shutdown"](.)
      t->expect(result)->Expect.toBe(())
    })
  })
})
```

### Unit Tests - LogRecordProcessor

**File:** `libs/frontman-nextjs/test/FrontmanNextjs__LogRecordProcessor.test.res`

```rescript
open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module LogRecordProcessor = FrontmanNextjs__LogRecordProcessor
module LogCapture = FrontmanNextjs__LogCapture

beforeAll(_t => {
  LogCapture.initialize()
})

describe("LogRecordProcessor", _t => {
  describe("Processor Creation", _t => {
    test("make returns valid processor object", t => {
      let processor = LogRecordProcessor.make()

      t->expect(processor["onEmit"])->Expect.toBeDefined
      t->expect(processor["forceFlush"])->Expect.toBeDefined
      t->expect(processor["shutdown"])->Expect.toBeDefined
    })
  })

  describe("Severity Mapping", _t => {
    test("maps ERROR severity to Error level", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "error message test unique 001",
        severityText: "ERROR",
        attributes: {}
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="error message test unique 001")
      let errorLogs = logs->Array.filter(log => log.level == Error)

      t->expect(errorLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps FATAL severity to Error level", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "fatal message test unique 002",
        severityText: "FATAL",
        attributes: {}
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="fatal message test unique 002")
      let errorLogs = logs->Array.filter(log => log.level == Error)

      t->expect(errorLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps WARN severity to Console level", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "warn message test unique 003",
        severityText: "WARN",
        attributes: {}
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="warn message test unique 003")
      let consoleLogs = logs->Array.filter(log => log.level == Console)

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps INFO severity to Console level", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "info message test unique 004",
        severityText: "INFO",
        attributes: {}
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="info message test unique 004")
      let consoleLogs = logs->Array.filter(log => log.level == Console)

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("defaults to Console level when severity missing", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "no severity test unique 005",
        attributes: {}
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="no severity test unique 005")
      let consoleLogs = logs->Array.filter(log => log.level == Console)

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })
  })

  describe("Timestamp Conversion", _t => {
    test("converts hrTime to ISO timestamp", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1704067200, 500_000_000],  // Specific time
        body: "timestamp test unique 006",
        severityText: "INFO"
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="timestamp test unique 006")
      let logWithTimestamp = logs->Array.find(log =>
        log.message == "timestamp test unique 006"
      )

      switch logWithTimestamp {
      | Some(log) => {
          // Should have ISO format timestamp
          t->expect(log.timestamp->String.includes("T"))->Expect.toBe(true)
          t->expect(log.timestamp->String.includes("Z"))->Expect.toBe(true)
        }
      | None => t->expect(false)->Expect.toBe(true)
      }
    })
  })

  describe("Attribute Passthrough", _t => {
    test("stores OTEL attributes in log entry", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "attributes test unique 007",
        severityText: "INFO",
        attributes: {
          "custom.key": "custom.value",
          "user.id": "12345"
        }
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="attributes test unique 007")
      let logWithAttrs = logs->Array.find(log =>
        log.message == "attributes test unique 007"
      )

      switch logWithAttrs {
      | Some(log) => {
          t->expect(log.attributes->Option.isSome)->Expect.toBe(true)

          switch log.attributes {
          | Some(attrs) => {
              let attrsStr = attrs->JSON.stringify
              t->expect(attrsStr->String.includes("custom.key"))->Expect.toBe(true)
            }
          | None => t->expect(false)->Expect.toBe(true)
          }
        }
      | None => t->expect(false)->Expect.toBe(true)
      }
    })

    test("handles missing attributes gracefully", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "no attributes test unique 008",
        severityText: "INFO"
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="no attributes test unique 008")
      let found = logs->Array.some(log =>
        log.message == "no attributes test unique 008"
      )

      t->expect(found)->Expect.toBe(true)
    })
  })

  describe("Body Handling", _t => {
    test("handles string body", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        body: "string body test unique 009",
        severityText: "INFO"
      }`)

      processor["onEmit"](. logRecord, None)

      let logs = LogCapture.getLogs(~pattern="string body test unique 009")
      let found = logs->Array.some(log =>
        log.message == "string body test unique 009"
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("handles missing body with empty string", t => {
      let processor = LogRecordProcessor.make()

      let logRecord = %raw(`{
        hrTime: [1000, 0],
        severityText: "INFO",
        attributes: { "test": "no body" }
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length

      processor["onEmit"](. logRecord, None)

      let afterCount = LogCapture.getLogs()->Array.length

      // Empty body should not create log entry
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })
  })

  describe("Error Handling", _t => {
    test("handles malformed log record gracefully", t => {
      let processor = LogRecordProcessor.make()

      let badRecord = %raw(`{
        // Missing required fields
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length

      // Should not crash
      processor["onEmit"](. badRecord, None)

      // Should still work after error
      t->expect(true)->Expect.toBe(true)
    })
  })

  describe("Async Methods", _t => {
    testAsync("forceFlush resolves successfully", async t => {
      let processor = LogRecordProcessor.make()
      let result = await processor["forceFlush"](.)
      t->expect(result)->Expect.toBe(())
    })

    testAsync("shutdown resolves successfully", async t => {
      let processor = LogRecordProcessor.make()
      let result = await processor["shutdown"](.)
      t->expect(result)->Expect.toBe(())
    })
  })
})
```

### Integration Tests

**File:** `libs/frontman-nextjs/test/FrontmanNextjs__OpenTelemetry__Integration.test.res`

```rescript
open Vitest

module OpenTelemetry = FrontmanNextjs__OpenTelemetry
module LogCapture = FrontmanNextjs__LogCapture

beforeAll(_t => {
  LogCapture.initialize()
})

describe("OpenTelemetry Integration", _t => {
  test("both processors can be created and used together", t => {
    let (logProcessor, spanProcessor) = OpenTelemetry.makeProcessors()

    t->expect(logProcessor)->Expect.toBeDefined
    t->expect(spanProcessor)->Expect.toBeDefined
  })

  test("span and log processors write to same buffer", t => {
    let (logProcessor, spanProcessor) = OpenTelemetry.makeProcessors()

    let beforeCount = LogCapture.getLogs()->Array.length

    // Emit a log record
    let logRecord = %raw(`{
      hrTime: [1000, 0],
      body: "integration test log",
      severityText: "INFO"
    }`)

    logProcessor["onEmit"](. logRecord, None)

    // Process a span
    let span = %raw(`{
      name: "test span",
      kind: 1,
      startTime: [1000, 0],
      endTime: [1001, 0],
      attributes: {
        "next.span_type": "BaseServer.handleRequest",
        "http.method": "GET",
        "http.route": "/integration"
      }
    }`)

    spanProcessor["onEnd"](. span)

    let afterCount = LogCapture.getLogs()->Array.length

    // Should have added 2 entries
    t->expect(afterCount)->Expect.toBe(beforeCount + 2)
  })
})
```

### End-to-End Test (Manual/Documentation)

**File:** `docs/OTEL_TESTING.md`

Manual test procedure for Next.js app integration:

1. Create test Next.js app with OTEL
2. Add Frontman middleware
3. Configure processors in instrumentation.ts
4. Make requests, verify logs captured
5. Test without OTEL installed - should not crash
6. Test browser-side - processors not used
7. Verify logs appear in OTEL collector

### Test Execution

**Update:** `libs/frontman-nextjs/package.json`
```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage"
  }
}
```

### Coverage Goals

- Unit tests: >90% coverage for:
  - Bindings module
  - SpanProcessor module
  - LogRecordProcessor module
  - OpenTelemetry module
- Integration tests: All processor combinations
- Edge cases: All error paths covered
- Backwards compatibility: Existing tests still pass

## Rollout Plan

### Phase 1: Implementation
1. Create bindings
2. Port processors
3. Add tests
4. Verify builds cleanly

### Phase 2: Testing
1. Test without OTEL installed (must work)
2. Test with OTEL installed (processors work)
3. Test in Next.js app with real OTEL collector
4. Performance benchmarking

### Phase 3: Documentation
1. Write README_OTEL.md
2. Add usage examples
3. Update main README

### Phase 4: Release
1. Publish as minor version (non-breaking)
2. Announce in changelog
3. Monitor for issues

## Success Criteria

✅ Existing logging works without OTEL
✅ Processors export to OTEL when configured
✅ No performance impact when OTEL not installed
✅ < 5% overhead with OTEL enabled
✅ All tests pass
✅ Zero TypeScript in implementation (pure ReScript)
✅ Matches Tidewave architecture
✅ Processors align with Tidewave behavior
✅ Clean build (no warnings)
✅ Backwards compatible

## Decisions (Aligned with Tidewave)

Based on Tidewave's implementation:

1. **Resource detection: NO**
   - Tidewave doesn't add custom resource detection
   - Let OTEL SDK handle automatic resource detection
   - **Decision:** Don't add custom resource fields

2. **Processor configuration: NO**
   - Tidewave processors are not configurable
   - Hard-coded span types and path filtering
   - **Decision:** Keep processors simple, non-configurable (like Tidewave)

3. **Batching: NO**
   - Tidewave writes immediately to buffer
   - Synchronous, no batching
   - **Decision:** Immediate write (matches Tidewave)

4. **OTEL metrics for buffer stats: NO**
   - Tidewave doesn't export metrics
   - Would add complexity and dependencies
   - **Decision:** No metrics export (future enhancement if needed)

5. **Browser support: NO**
   - Tidewave only supports Node.js (checks `isBrowser` and skips)
   - We already have browser detection in LogCapture
   - **Decision:** Node.js only (processors won't be used in browser)

All decisions align with Tidewave's simple, focused approach.
