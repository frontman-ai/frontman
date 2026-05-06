open Vitest

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings
module LogRecordProcessor = FrontmanNextjs__LogRecordProcessor
module LogCapture = FrontmanNextjs__LogCapture

// External bindings to call processor methods from tests
type processor
@send
external onEmit: (processor, Bindings.Logs.sdkLogRecord, option<Bindings.context>) => unit =
  "onEmit"
@send external forceFlush: processor => promise<unit> = "forceFlush"
@send external shutdown: processor => promise<unit> = "shutdown"

beforeAll(_t => {
  LogCapture.initialize()
})

describe("LogRecordProcessor", _t => {
  describe("Processor Creation", _t => {
    test(
      "make creates processor without errors",
      t => {
        let _: processor = LogRecordProcessor.make()->Obj.magic
        // If we get here without throwing, the processor was created successfully
        t->expect(true)->Expect.toBe(true)
      },
    )
  })

  describe("Severity Mapping", _t => {
    test(
      "maps ERROR severity to Error level",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "error message test unique 001",
        severityText: "ERROR",
        attributes: {}
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="error message test unique 001")
        let errorLogs = logs->Array.filter(log => log.level == Error)

        t->expect(errorLogs->Array.length > 0)->Expect.toBe(true)
      },
    )

    test(
      "maps WARN severity to Console level",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "warn message test unique 003",
        severityText: "WARN",
        attributes: {}
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="warn message test unique 003")
        let consoleLogs = logs->Array.filter(log => log.level == Console)

        t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
      },
    )

    test(
      "defaults to Console level when severity missing",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "no severity test unique 005",
        attributes: {}
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="no severity test unique 005")
        let consoleLogs = logs->Array.filter(log => log.level == Console)

        t->expect(consoleLogs->Array.length > 0)->Expect.toBe(true)
      },
    )
  })

  describe("Attribute Passthrough", _t => {
    test(
      "stores OTEL attributes in log entry",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "attributes test unique 007",
        severityText: "INFO",
        attributes: {
          "custom.key": "custom.value",
          "user.id": "12345"
        }
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="attributes test unique 007")
        let logWithAttrs = logs->Array.find(log => log.message == "attributes test unique 007")

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
      },
    )

    test(
      "handles missing attributes gracefully",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "no attributes test unique 008",
        severityText: "INFO"
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="no attributes test unique 008")
        let found = logs->Array.some(log => log.message == "no attributes test unique 008")

        t->expect(found)->Expect.toBe(true)
      },
    )
  })

  describe("Body Handling", _t => {
    test(
      "handles string body",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        body: "string body test unique 009",
        severityText: "INFO"
      }`)

        proc->onEmit(logRecord, None)

        let logs = LogCapture.getLogs(~pattern="string body test unique 009")
        let found = logs->Array.some(log => log.message == "string body test unique 009")

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "handles missing body with empty string",
      t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic

        let logRecord: Bindings.Logs.sdkLogRecord = %raw(`{
        hrTime: [1000, 0],
        severityText: "INFO",
        attributes: { "test": "no body" }
      }`)

        let beforeCount = LogCapture.getLogs()->Array.length

        proc->onEmit(logRecord, None)

        let afterCount = LogCapture.getLogs()->Array.length

        // Empty body should not create log entry (stripped by LogCapture)
        t->expect(afterCount)->Expect.toBe(beforeCount)
      },
    )
  })

  describe("Async Methods", _t => {
    testAsync(
      "forceFlush resolves successfully",
      async t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic
        let result = await proc->forceFlush
        t->expect(result)->Expect.toBe()
      },
    )

    testAsync(
      "shutdown resolves successfully",
      async t => {
        let proc: processor = LogRecordProcessor.make()->Obj.magic
        let result = await proc->shutdown
        t->expect(result)->Expect.toBe()
      },
    )
  })
})
