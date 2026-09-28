module LogCapture = FrontmanNextjs__LogCapture
module Sentry = FrontmanNextjs__Sentry
module RuntimeEnv = FrontmanNextjs__RuntimeEnv
open FrontmanNextjs__OpenTelemetry__Bindings

let noopLogRecordProcessor = (): Logs.logRecordProcessor =>
  Logs.makeProcessor({
    "onEmit": (_logRecord, _context) => (),
    "forceFlush": () => Promise.resolve(),
    "shutdown": () => Promise.resolve(),
  })

let noopSpanProcessor = (): Trace.spanProcessor =>
  Trace.makeProcessor({
    "onStart": (_span, _context) => (),
    "onEnd": _span => (),
    "forceFlush": () => Promise.resolve(),
    "shutdown": () => Promise.resolve(),
  })

@@live
let setup = (): (Logs.logRecordProcessor, Trace.spanProcessor) => {
  switch RuntimeEnv.isRuntimeEnabled() {
  | true =>
    LogCapture.initialize()
    Sentry.initialize()

    (FrontmanNextjs__LogRecordProcessor.make(), FrontmanNextjs__SpanProcessor.make())
  | false => (noopLogRecordProcessor(), noopSpanProcessor())
  }
}
