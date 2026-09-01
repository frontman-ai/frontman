open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module SpanProcessor = FrontmanNextjs__SpanProcessor
module LogCapture = FrontmanNextjs__LogCapture

@new @module("@opentelemetry/sdk-trace-node")
external makeBasicTracerProvider: {..} => Bindings.Trace.tracerProvider = "BasicTracerProvider"

@send
external getTracer: (Bindings.Trace.tracerProvider, string) => Bindings.Trace.tracer = "getTracer"

@send
external startSpan: (Bindings.Trace.tracer, string) => Bindings.Trace.span = "startSpan"

@send
external setAttribute: (Bindings.Trace.span, string, 'a) => unit = "setAttribute"

@send external spanEnd: Bindings.Trace.span => unit = "end"

@send
external forceFlush: Bindings.Trace.tracerProvider => promise<unit> = "forceFlush"

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

module TestHelpers = {
  type testContext = {
    provider: Bindings.Trace.tracerProvider,
    tracer: Bindings.Trace.tracer,
  }

  let setup = (): testContext => {
    let provider = makeBasicTracerProvider({"spanProcessors": [SpanProcessor.make()]})
    let tracer = provider->getTracer("test")
    {provider, tracer}
  }

  let executeSpan = async (ctx: testContext, span: Bindings.Trace.span): unit => {
    span->spanEnd
    await ctx.provider->forceFlush
  }

  let executeSpans = async (ctx: testContext, spans: array<Bindings.Trace.span>): unit => {
    spans->Array.forEach(span => span->spanEnd)
    await ctx.provider->forceFlush
  }

  let getSingleLog = (~pattern=?, ~level=?): LogCapture.logEntry => {
    let logs = LogCapture.getLogs(~pattern?, ~level?)
    logs[0]->Option.getOrThrow
  }

  let assertMessageContains = (t, message: string, parts: array<string>): unit => {
    parts->Array.forEach(part => {
      t->expect(message->String.includes(part))->Expect.toBe(true)
    })
  }

  let assertNoNewLogs = async (_ctx: testContext, testFn: unit => promise<unit>): bool => {
    let beforeCount = LogCapture.getLogs()->Array.length
    await testFn()
    let afterCount = LogCapture.getLogs()->Array.length
    beforeCount == afterCount
  }

  let assertHasAttribute = (t, log: LogCapture.logEntry, key: string, expected: 'a): unit => {
    switch log.attributes {
    | Some(attrs) => {
        let value = attrs->Obj.magic->Dict.get(key)->Option.getOrThrow->Obj.magic
        t->expect(value)->Expect.toBe(expected)
      }
    | None => t->expect(false)->Expect.toBe(true)
    }
  }
}

let clearLogs = (): unit => {
  let state = LogCapture.getInstance()
  state.buffer := FrontmanNextjs__CircularBuffer.make(~capacity=1024)
}

beforeAll(() => {
  LogCapture.initialize()
})

afterEach(() => {
  clearLogs()
})

describe("SpanProcessor Integration Tests", _t => {
  describe("BaseServer.handleRequest - HTTP Request Spans", _t => {
    testAsync(
      "processes successful GET request with full log structure",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "GET",
            route: "/api/users",
            statusCode: 200.0,
          },
        )
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/api/users")

        TestHelpers.assertMessageContains(t, log.message, ["GET", "/api/users", "200", "ms"])

        t->expect(log.level)->Expect.toBe(LogCapture.Console)

        TestHelpers.assertHasAttribute(t, log, "log.origin", "opentelemetry-span")
        TestHelpers.assertHasAttribute(t, log, "http.method", "GET")
        TestHelpers.assertHasAttribute(t, log, "http.route", "/api/users")
        TestHelpers.assertHasAttribute(t, log, "http.status_code", 200.0)
        TestHelpers.assertHasAttribute(t, log, "span.type", "BaseServer.handleRequest")

        switch log.attributes {
        | Some(attrs) => t->expect(Dict.has(attrs->Obj.magic, "duration.ms"))->Expect.toBe(true)
        | None => t->expect(false)->Expect.toBe(true)
        }

        let logTime = log.timestamp->Date.fromString->Date.getTime
        t->expect(Date.now() -. logTime)->Expect.Float.toBeLessThan(5000.0)
      },
    )

    testAsync(
      "maps 5xx status codes to Error level",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "POST",
            route: "/api/fail",
            statusCode: 500.0,
          },
        )
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~level=LogCapture.Error)
        TestHelpers.assertMessageContains(t, log.message, ["POST", "/api/fail", "500"])
        t->expect(log.level)->Expect.toBe(LogCapture.Error)
      },
    )

    testAsync(
      "maps 4xx status codes to Console level (not errors)",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "GET",
            route: "/api/not-found",
            statusCode: 404.0,
          },
        )
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/api/not-found")
        t->expect(log.level)->Expect.toBe(LogCapture.Console)
      },
    )

    testAsync(
      "maps 3xx status codes to Console level",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "GET",
            route: "/redirect",
            statusCode: 302.0,
          },
        )
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/redirect")
        t->expect(log.level)->Expect.toBe(LogCapture.Console)
      },
    )
  })

  describe("AppRender.getBodyResult - Page Render Spans", _t => {
    testAsync(
      "processes page render spans with correct message format",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeAppRenderSpan(ctx.tracer, "/dashboard")
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="Rendered route")
        TestHelpers.assertMessageContains(t, log.message, ["Rendered route:", "/dashboard", "ms"])
        t->expect(log.level)->Expect.toBe(LogCapture.Console)
      },
    )
  })

  describe("AppRouteRouteHandlers.runHandler - API Handler Spans", _t => {
    testAsync(
      "processes API handler spans with correct message format",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeApiHandlerSpan(ctx.tracer, "/api/data")
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="API route")
        TestHelpers.assertMessageContains(t, log.message, ["API route:", "/api/data", "ms"])
        t->expect(log.level)->Expect.toBe(LogCapture.Console)
      },
    )
  })

  describe("Realistic Multi-Span Scenarios", _t => {
    testAsync(
      "Next.js page request creates multiple logs in correct order",
      async t => {
        let ctx = TestHelpers.setup()

        let httpSpan = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "GET",
            route: "/dashboard",
            statusCode: 200.0,
          },
        )
        let renderSpan = Fixtures.makeAppRenderSpan(ctx.tracer, "/dashboard")

        await ctx->TestHelpers.executeSpans([httpSpan, renderSpan])

        let logs = LogCapture.getLogs()
        t->expect(logs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(2)

        let hasHttpLog = logs->Array.some(log => log.message->String.includes("GET /dashboard 200"))
        let hasRenderLog =
          logs->Array.some(log => log.message->String.includes("Rendered route: /dashboard"))

        t->expect(hasHttpLog)->Expect.toBe(true)
        t->expect(hasRenderLog)->Expect.toBe(true)
      },
    )

    testAsync(
      "API route request creates API handler log",
      async t => {
        let ctx = TestHelpers.setup()

        let httpSpan = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "POST",
            route: "/api/submit",
            statusCode: 201.0,
          },
        )
        let handlerSpan = Fixtures.makeApiHandlerSpan(ctx.tracer, "/api/submit")

        await ctx->TestHelpers.executeSpans([httpSpan, handlerSpan])

        let logs = LogCapture.getLogs(~pattern="/api/submit")
        t->expect(logs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(2)

        let hasHttpLog =
          logs->Array.some(log => log.message->String.includes("POST /api/submit 201"))
        let hasHandlerLog =
          logs->Array.some(log => log.message->String.includes("API route: /api/submit"))

        t->expect(hasHttpLog)->Expect.toBe(true)
        t->expect(hasHandlerLog)->Expect.toBe(true)
      },
    )
  })

  describe("Filtering Logic", _t => {
    testAsync(
      "filters out /frontman paths",
      async t => {
        let ctx = TestHelpers.setup()

        let noNewLogs = await ctx->TestHelpers.assertNoNewLogs(
          async () => {
            let span = Fixtures.makeBaseServerSpan(
              ctx.tracer,
              {
                method: "GET",
                route: "/frontman/logs",
                statusCode: 200.0,
              },
            )
            await ctx->TestHelpers.executeSpan(span)
          },
        )

        t->expect(noNewLogs)->Expect.toBe(true)
      },
    )

    testAsync(
      "filters out /frontman subpaths",
      async t => {
        let ctx = TestHelpers.setup()

        let noNewLogs = await ctx->TestHelpers.assertNoNewLogs(
          async () => {
            let span = Fixtures.makeBaseServerSpan(
              ctx.tracer,
              {
                method: "POST",
                route: "/frontman/api/tools",
                statusCode: 200.0,
              },
            )
            await ctx->TestHelpers.executeSpan(span)
          },
        )

        t->expect(noNewLogs)->Expect.toBe(true)
      },
    )

    testAsync(
      "filters out public and internal MCP paths",
      async t => {
        let ctx = TestHelpers.setup()

        let noNewLogs = await ctx->TestHelpers.assertNoNewLogs(
          async () => {
            await ctx->TestHelpers.executeSpans([
              Fixtures.makeBaseServerSpan(
                ctx.tracer,
                {method: "POST", route: "/mcp", statusCode: 200.0},
              ),
              Fixtures.makeBaseServerSpan(
                ctx.tracer,
                {method: "POST", route: "/api/frontman-mcp", statusCode: 200.0},
              ),
            ])
          },
        )

        t->expect(noNewLogs)->Expect.toBe(true)
      },
    )

    testAsync(
      "ignores irrelevant span types",
      async t => {
        let ctx = TestHelpers.setup()

        let noNewLogs = await ctx->TestHelpers.assertNoNewLogs(
          async () => {
            let span = ctx.tracer->startSpan("some random operation")
            span->setAttribute("next.span_type", "NextNodeServer.findPageComponents")
            await ctx->TestHelpers.executeSpan(span)
          },
        )

        t->expect(noNewLogs)->Expect.toBe(true)
      },
    )
  })

  describe("Edge Cases and Error Handling", _t => {
    testAsync(
      "handles missing http.route with next.route fallback",
      async t => {
        let ctx = TestHelpers.setup()

        let span = ctx.tracer->startSpan("page render")
        span->setAttribute("next.span_type", "AppRender.getBodyResult")
        span->setAttribute("next.route", "/about")
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/about")
        TestHelpers.assertMessageContains(t, log.message, ["/about"])
      },
    )

    testAsync(
      "handles missing status code gracefully",
      async t => {
        let ctx = TestHelpers.setup()

        let span = ctx.tracer->startSpan("GET /test")
        span->setAttribute("next.span_type", "BaseServer.handleRequest")
        span->setAttribute("http.method", "GET")
        span->setAttribute("http.route", "/test")
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/test")
        TestHelpers.assertMessageContains(t, log.message, ["unknown"])
      },
    )

    testAsync(
      "handles missing http.method gracefully",
      async t => {
        let ctx = TestHelpers.setup()

        let span = ctx.tracer->startSpan("request")
        span->setAttribute("next.span_type", "BaseServer.handleRequest")
        span->setAttribute("http.route", "/test")
        span->setAttribute("http.status_code", 200.0)
        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/test")
        TestHelpers.assertMessageContains(t, log.message, ["UNKNOWN"])
      },
    )

    testAsync(
      "handles span with no attributes gracefully",
      async t => {
        let ctx = TestHelpers.setup()

        let noNewLogs = await ctx->TestHelpers.assertNoNewLogs(
          async () => {
            let span = ctx.tracer->startSpan("empty span")
            await ctx->TestHelpers.executeSpan(span)
          },
        )

        t->expect(noNewLogs)->Expect.toBe(true)
      },
    )
  })

  describe("Duration Calculation", _t => {
    testAsync(
      "calculates duration from hrTime accurately",
      async t => {
        let ctx = TestHelpers.setup()

        let span = Fixtures.makeBaseServerSpan(
          ctx.tracer,
          {
            method: "GET",
            route: "/slow",
            statusCode: 200.0,
          },
        )

        await Promise.make(
          (resolve, _reject) => {
            setTimeout(() => resolve(), 50)->ignore
          },
        )

        await ctx->TestHelpers.executeSpan(span)

        let log = TestHelpers.getSingleLog(~pattern="/slow")
        TestHelpers.assertMessageContains(t, log.message, ["/slow", "ms"])

        switch log.attributes {
        | Some(attrs) => {
            let duration = attrs->Obj.magic->Dict.get("duration.ms")
            switch duration {
            | Some(d) => {
                let durationValue = d->Obj.magic
                t->expect(durationValue)->Expect.Float.toBeGreaterThanOrEqual(40.0)
                t->expect(durationValue)->Expect.Float.toBeLessThan(200.0)
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })
})
