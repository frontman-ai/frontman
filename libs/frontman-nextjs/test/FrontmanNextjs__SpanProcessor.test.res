// Integration tests for SpanProcessor with real OpenTelemetry
// Tests the complete pipeline: OTEL Tracer → Span → Processor → LogCapture

open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module SpanProcessor = FrontmanNextjs__SpanProcessor
module LogCapture = FrontmanNextjs__LogCapture

// OTEL Setup - use real SDK for integration testing
@module("@opentelemetry/sdk-trace-node")
external makeBasicTracerProvider: unit => Bindings.Trace.tracerProvider = "BasicTracerProvider"

@send
external addSpanProcessor: (
  Bindings.Trace.tracerProvider,
  Bindings.Trace.spanProcessor,
) => unit = "addSpanProcessor"

@send
external getTracer: (Bindings.Trace.tracerProvider, string) => Bindings.Trace.tracer = "getTracer"

@send
external startSpan: (Bindings.Trace.tracer, string) => Bindings.Trace.span = "startSpan"

@send
external setAttribute: (Bindings.Trace.span, string, 'a) => unit = "setAttribute"

@send external spanEnd: Bindings.Trace.span => unit = "end"

@send
external forceFlush: Bindings.Trace.tracerProvider => promise<unit> = "forceFlush"

// Test fixtures - use real OTEL API to create spans
module Fixtures = {
  type httpRequest = {
    method: string,
    route: string,
    statusCode: float,
  }

  let makeBaseServerSpan = (tracer, request: httpRequest): Bindings.Trace.span => {
    let span = tracer->startSpan(`${request.method} ${request.route}`)
    span->setAttribute("next.span_type", "BaseServer.handleRequest")
    span->setAttribute("http.method", request.method)
    span->setAttribute("http.route", request.route)
    span->setAttribute("http.status_code", request.statusCode)
    span
  }

  let makeAppRenderSpan = (tracer, route: string): Bindings.Trace.span => {
    let span = tracer->startSpan("render " ++ route)
    span->setAttribute("next.span_type", "AppRender.getBodyResult")
    span->setAttribute("next.route", route)
    span
  }

  let makeApiHandlerSpan = (tracer, route: string): Bindings.Trace.span => {
    let span = tracer->startSpan("handler " ++ route)
    span->setAttribute("next.span_type", "AppRouteRouteHandlers.runHandler")
    span->setAttribute("http.route", route)
    span
  }
}

// Helper to clear logs between tests for isolation
let clearLogs = (): unit => {
  let state = LogCapture.getInstance()
  state.buffer := FrontmanNextjs__CircularBuffer.make(~capacity=1024)
}

// Initialize LogCapture before tests
beforeAll(_t => {
  LogCapture.initialize()
})

// Clear logs after each test for isolation
afterEach(_t => {
  clearLogs()
})

describe("SpanProcessor Integration Tests", _t => {
  describe("BaseServer.handleRequest - HTTP Request Spans", _t => {
    testAsync("processes successful GET request with full log structure", async t => {
      // Arrange
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      // Act
      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/api/users",
        statusCode: 200.0,
      })
      span->spanEnd
      await provider->forceFlush

      // Assert
      let logs = LogCapture.getLogs(~pattern="/api/users")
      t->expect(logs->Array.length)->Expect.toBe(1)

      let log = logs[0]->Option.getOrThrow

      // Verify message format contains expected parts: "METHOD /path STATUS DURATIONms"
      t->expect(log.message->String.includes("GET"))->Expect.toBe(true)
      t->expect(log.message->String.includes("/api/users"))->Expect.toBe(true)
      t->expect(log.message->String.includes("200"))->Expect.toBe(true)
      t->expect(log.message->String.includes("ms"))->Expect.toBe(true)

      // Verify log level
      t->expect(log.level)->Expect.toBe(LogCapture.Console)

      // Verify complete attributes structure
      switch log.attributes {
      | Some(attrs) => {
          let attrsObj = attrs->Obj.magic
          t->expect(attrsObj["log.origin"])->Expect.toBe("opentelemetry-span")
          t->expect(attrsObj["http.method"])->Expect.toBe("GET")
          t->expect(attrsObj["http.route"])->Expect.toBe("/api/users")
          t->expect(attrsObj["http.status_code"])->Expect.toBe(200.0)
          t->expect(attrsObj["span.type"])->Expect.toBe("BaseServer.handleRequest")
          // Verify duration.ms attribute exists
          let hasDuration = Dict.has(attrsObj, "duration.ms")
          t->expect(hasDuration)->Expect.toBe(true)
        }
      | None => t->expect(false)->Expect.toBe(true) // Fail if no attributes
      }

      // Verify timestamp is recent (within last 5 seconds)
      let logTime = log.timestamp->Date.fromString->Date.getTime
      let now = Date.now()
      t->expect(now -. logTime)->Expect.Float.toBeLessThan(5000.0)
    })

    testAsync("maps 5xx status codes to Error level", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "POST",
        route: "/api/fail",
        statusCode: 500.0,
      })
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~level=LogCapture.Error)
      t->expect(logs->Array.length)->Expect.toBe(1)

      let log = logs[0]->Option.getOrThrow
      t->expect(log.message->String.includes("POST"))->Expect.toBe(true)
      t->expect(log.message->String.includes("/api/fail"))->Expect.toBe(true)
      t->expect(log.message->String.includes("500"))->Expect.toBe(true)
      t->expect(log.level)->Expect.toBe(LogCapture.Error)
    })

    testAsync("maps 4xx status codes to Console level (not errors)", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/api/not-found",
        statusCode: 404.0,
      })
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/api/not-found")
      t->expect(logs->Array.length)->Expect.toBe(1)
      t->expect((logs[0]->Option.getOrThrow).level)->Expect.toBe(LogCapture.Console)
    })

    testAsync("maps 3xx status codes to Console level", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/redirect",
        statusCode: 302.0,
      })
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/redirect")
      t->expect(logs->Array.length)->Expect.toBe(1)
      t->expect((logs[0]->Option.getOrThrow).level)->Expect.toBe(LogCapture.Console)
    })
  })

  describe("AppRender.getBodyResult - Page Render Spans", _t => {
    testAsync("processes page render spans with correct message format", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeAppRenderSpan(tracer, "/dashboard")
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="Rendered route")
      t->expect(logs->Array.length)->Expect.toBe(1)

      let log = logs[0]->Option.getOrThrow
      // Verify format: "Rendered route: /path (DURATIONms)"
      t->expect(log.message->String.includes("Rendered route:"))->Expect.toBe(true)
      t->expect(log.message->String.includes("/dashboard"))->Expect.toBe(true)
      t->expect(log.message->String.includes("ms"))->Expect.toBe(true)
      t->expect(log.level)->Expect.toBe(LogCapture.Console)
    })
  })

  describe("AppRouteRouteHandlers.runHandler - API Handler Spans", _t => {
    testAsync("processes API handler spans with correct message format", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeApiHandlerSpan(tracer, "/api/data")
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="API route")
      t->expect(logs->Array.length)->Expect.toBe(1)

      let log = logs[0]->Option.getOrThrow
      // Verify format: "API route: /path (DURATIONms)"
      t->expect(log.message->String.includes("API route:"))->Expect.toBe(true)
      t->expect(log.message->String.includes("/api/data"))->Expect.toBe(true)
      t->expect(log.message->String.includes("ms"))->Expect.toBe(true)
      t->expect(log.level)->Expect.toBe(LogCapture.Console)
    })
  })

  describe("Realistic Multi-Span Scenarios", _t => {
    testAsync("Next.js page request creates multiple logs in correct order", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      // Simulate a page request that triggers multiple span types
      let httpSpan = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/dashboard",
        statusCode: 200.0,
      })
      let renderSpan = Fixtures.makeAppRenderSpan(tracer, "/dashboard")

      httpSpan->spanEnd
      renderSpan->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs()
      t->expect(logs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(2)

      // Verify we got both log types
      let hasHttpLog =
        logs->Array.some(log => log.message->String.includes("GET /dashboard 200"))
      let hasRenderLog =
        logs->Array.some(log => log.message->String.includes("Rendered route: /dashboard"))

      t->expect(hasHttpLog)->Expect.toBe(true)
      t->expect(hasRenderLog)->Expect.toBe(true)
    })

    testAsync("API route request creates API handler log", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let httpSpan = Fixtures.makeBaseServerSpan(tracer, {
        method: "POST",
        route: "/api/submit",
        statusCode: 201.0,
      })
      let handlerSpan = Fixtures.makeApiHandlerSpan(tracer, "/api/submit")

      httpSpan->spanEnd
      handlerSpan->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/api/submit")
      t->expect(logs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(2)

      let hasHttpLog =
        logs->Array.some(log => log.message->String.includes("POST /api/submit 201"))
      let hasHandlerLog =
        logs->Array.some(log => log.message->String.includes("API route: /api/submit"))

      t->expect(hasHttpLog)->Expect.toBe(true)
      t->expect(hasHandlerLog)->Expect.toBe(true)
    })
  })

  describe("Filtering Logic", _t => {
    testAsync("filters out /frontman paths", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let beforeCount = LogCapture.getLogs()->Array.length

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/frontman/logs",
        statusCode: 200.0,
      })
      span->spanEnd
      await provider->forceFlush

      let afterCount = LogCapture.getLogs()->Array.length
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })

    testAsync("filters out /frontman subpaths", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let beforeCount = LogCapture.getLogs()->Array.length

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "POST",
        route: "/frontman/api/tools",
        statusCode: 200.0,
      })
      span->spanEnd
      await provider->forceFlush

      let afterCount = LogCapture.getLogs()->Array.length
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })

    testAsync("ignores irrelevant span types", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let beforeCount = LogCapture.getLogs()->Array.length

      let span = tracer->startSpan("some random operation")
      span->setAttribute("next.span_type", "NextNodeServer.findPageComponents")
      span->spanEnd
      await provider->forceFlush

      let afterCount = LogCapture.getLogs()->Array.length
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })
  })

  describe("Edge Cases and Error Handling", _t => {
    testAsync("handles missing http.route with next.route fallback", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = tracer->startSpan("page render")
      span->setAttribute("next.span_type", "AppRender.getBodyResult")
      span->setAttribute("next.route", "/about")
      // Note: no http.route attribute
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/about")
      t->expect(logs->Array.length)->Expect.toBe(1)
      t->expect((logs[0]->Option.getOrThrow).message->String.includes("/about"))->Expect.toBe(true)
    })

    testAsync("handles missing status code gracefully", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = tracer->startSpan("GET /test")
      span->setAttribute("next.span_type", "BaseServer.handleRequest")
      span->setAttribute("http.method", "GET")
      span->setAttribute("http.route", "/test")
      // Note: no http.status_code attribute
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/test")
      t->expect(logs->Array.length)->Expect.toBe(1)
      t->expect((logs[0]->Option.getOrThrow).message->String.includes("unknown"))->Expect.toBe(true)
    })

    testAsync("handles missing http.method gracefully", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = tracer->startSpan("request")
      span->setAttribute("next.span_type", "BaseServer.handleRequest")
      span->setAttribute("http.route", "/test")
      span->setAttribute("http.status_code", 200.0)
      // Note: no http.method attribute
      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/test")
      t->expect(logs->Array.length)->Expect.toBe(1)
      t->expect((logs[0]->Option.getOrThrow).message->String.includes("UNKNOWN"))->Expect.toBe(true)
    })

    testAsync("handles span with no attributes gracefully", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let beforeCount = LogCapture.getLogs()->Array.length

      let span = tracer->startSpan("empty span")
      // No attributes at all
      span->spanEnd
      await provider->forceFlush

      let afterCount = LogCapture.getLogs()->Array.length
      // Should not crash, just ignore the span
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })
  })

  describe("Duration Calculation", _t => {
    testAsync("calculates duration from hrTime accurately", async t => {
      let provider = makeBasicTracerProvider()
      provider->addSpanProcessor(SpanProcessor.make())
      let tracer = provider->getTracer("test")

      let span = Fixtures.makeBaseServerSpan(tracer, {
        method: "GET",
        route: "/slow",
        statusCode: 200.0,
      })

      // Simulate some processing time
      await Promise.make((resolve, _reject) => {
        setTimeout(() => resolve(), 50)->ignore
      })

      span->spanEnd
      await provider->forceFlush

      let logs = LogCapture.getLogs(~pattern="/slow")
      t->expect(logs->Array.length)->Expect.toBe(1)

      let log = logs[0]->Option.getOrThrow
      // Duration should be >= 50ms (with some tolerance for overhead)
      t->expect(log.message->String.includes("ms"))->Expect.toBe(true)
      t->expect(log.message->String.includes("/slow"))->Expect.toBe(true)

      // Verify attributes.duration.ms exists and is reasonable
      switch log.attributes {
      | Some(attrs) => {
          let duration = attrs->Obj.magic->Dict.get("duration.ms")
          switch duration {
          | Some(d) => {
              let durationValue = d->Obj.magic
              t->expect(durationValue)->Expect.Float.toBeGreaterThan(50.0)
              t->expect(durationValue)->Expect.Float.toBeLessThan(200.0) // Generous upper bound
            }
          | None => t->expect(false)->Expect.toBe(true) // Fail if no duration
          }
        }
      | None => t->expect(false)->Expect.toBe(true) // Fail if no attributes
      }
    })
  })
})
