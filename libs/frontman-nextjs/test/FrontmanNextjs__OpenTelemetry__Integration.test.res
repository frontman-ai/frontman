open Vitest

module OpenTelemetry = FrontmanNextjs__OpenTelemetry
module LogCapture = FrontmanNextjs__LogCapture
module Bindings = FrontmanNextjs__OpenTelemetry__Bindings

// External bindings for processor methods
type logProcessor
@send
external logOnEmit: (logProcessor, Bindings.Logs.sdkLogRecord, option<Bindings.context>) => unit =
  "onEmit"

type spanProcessor
@send external spanOnEnd: (spanProcessor, Bindings.Trace.readableSpan) => unit = "onEnd"

beforeAll(_t => {
  LogCapture.initialize()
})

describe("OpenTelemetry Integration", _t => {
  test("both processors can be created together", t => {
    let (_logProc: logProcessor, _spanProc: spanProcessor) =
      OpenTelemetry.makeProcessors()->Obj.magic
    // If we get here without throwing, both processors were created successfully
    t->expect(true)->Expect.toBe(true)
  })

  test("span and log processors write to same buffer", t => {
    let (logProc: logProcessor, spanProc: spanProcessor) = OpenTelemetry.makeProcessors()->Obj.magic

    let beforeCount = LogCapture.getLogs()->Array.length

    // Emit a log record
    let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
      hrTime: [1000, 0],
      body: "integration test log",
      severityText: "INFO"
    }`)

    logProc->logOnEmit(logRecord, None)

    // Process a span
    let span: Bindings.Trace.readableSpan = %raw(`{
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

    spanProc->spanOnEnd(span)

    let afterCount = LogCapture.getLogs()->Array.length

    // Should have added 2 entries
    t->expect(afterCount)->Expect.toBe(beforeCount + 2)
  })

  test("processors can be created individually", t => {
    let _: logProcessor = OpenTelemetry.makeLogRecordProcessor()->Obj.magic
    let _: spanProcessor = OpenTelemetry.makeSpanProcessor()->Obj.magic
    // If we get here without throwing, both processors were created successfully
    t->expect(true)->Expect.toBe(true)
  })
})
