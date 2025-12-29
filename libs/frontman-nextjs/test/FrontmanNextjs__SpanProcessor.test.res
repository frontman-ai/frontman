open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module SpanProcessor = FrontmanNextjs__SpanProcessor
module LogCapture = FrontmanNextjs__LogCapture

// External bindings to call processor methods from tests
type processor
@send external onEnd: (processor, Bindings.Trace.readableSpan) => unit = "onEnd"
@send external forceFlush: processor => promise<unit> = "forceFlush"
@send external shutdown: processor => promise<unit> = "shutdown"

// Initialize LogCapture before tests
beforeAll(_t => {
  LogCapture.initialize()
})

describe("SpanProcessor", _t => {
  describe("Processor Creation", _t => {
    test("make creates processor without errors", t => {
      let _proc: processor = SpanProcessor.make()->Obj.magic
      // If we get here without throwing, the processor was created successfully
      t->expect(true)->Expect.toBe(true)
    })
  })

  describe("Span Filtering", _t => {
    test("only processes relevant span types", t => {
      let proc: processor = SpanProcessor.make()->Obj.magic

      // Mock span with irrelevant type
      let span: Bindings.Trace.readableSpan = %raw(`{
        name: "SomeOtherSpan",
        kind: 1,
        startTime: [1000, 0],
        endTime: [1001, 0],
        attributes: {
          "next.span_type": "SomeOtherType"
        }
      }`)

      let beforeCount = LogCapture.getLogs()->Array.length

      proc->onEnd(span)

      let afterCount = LogCapture.getLogs()->Array.length

      // Should not add log
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })

    test("processes BaseServer.handleRequest spans", t => {
      let proc: processor = SpanProcessor.make()->Obj.magic

      let span: Bindings.Trace.readableSpan = %raw(`{
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

      proc->onEnd(span)

      let logs = LogCapture.getLogs(~pattern="GET /api/test")
      let found = logs->Array.some(log =>
        log.message->String.includes("GET") &&
        log.message->String.includes("/api/test") &&
        log.message->String.includes("200")
      )

      t->expect(found)->Expect.toBe(true)
    })

    test("filters out /frontman paths", t => {
      let proc: processor = SpanProcessor.make()->Obj.magic

      let span: Bindings.Trace.readableSpan = %raw(`{
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
      proc->onEnd(span)
      let afterCount = LogCapture.getLogs()->Array.length

      // Should not add log for /frontman paths
      t->expect(afterCount)->Expect.toBe(beforeCount)
    })
  })

  describe("Log Level Mapping", _t => {
    test("maps 5xx status codes to Error level", t => {
      let proc: processor = SpanProcessor.make()->Obj.magic

      let span: Bindings.Trace.readableSpan = %raw(`{
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

      proc->onEnd(span)

      let logs = LogCapture.getLogs(~pattern="/api/fail")
      let errorLogs = logs->Array.filter(log =>
        log.level == Error && log.message->String.includes("/api/fail")
      )

      t->expect(errorLogs->Array.length > 0)->Expect.toBe(true)
    })

    test("maps 2xx status codes to Console level", t => {
      let proc: processor = SpanProcessor.make()->Obj.magic

      let span: Bindings.Trace.readableSpan = %raw(`{
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

      proc->onEnd(span)

      let logs = LogCapture.getLogs(~pattern="/api/success")
      let consoleLogs = logs->Array.filter(log =>
        log.level == Console && log.message->String.includes("/api/success")
      )

      t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
    })
  })

  describe("Async Methods", _t => {
    testAsync("forceFlush resolves successfully", async t => {
      let proc: processor = SpanProcessor.make()->Obj.magic
      let result = await proc->forceFlush
      t->expect(result)->Expect.toBe()
    })

    testAsync("shutdown resolves successfully", async t => {
      let proc: processor = SpanProcessor.make()->Obj.magic
      let result = await proc->shutdown
      t->expect(result)->Expect.toBe()
    })
  })
})
