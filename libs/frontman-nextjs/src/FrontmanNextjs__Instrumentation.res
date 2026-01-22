module LogCapture = FrontmanNextjs__LogCapture
module Sentry = FrontmanNextjs__Sentry

let setup = (): (
  FrontmanNextjs__OpenTelemetry__Bindings.Logs.logRecordProcessor,
  FrontmanNextjs__OpenTelemetry__Bindings.Trace.spanProcessor,
) => {
  LogCapture.initialize()
  Sentry.initialize()

  (FrontmanNextjs__LogRecordProcessor.make(), FrontmanNextjs__SpanProcessor.make())
}
