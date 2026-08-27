module LogCapture = FrontmanNextjs__LogCapture
module Sentry = FrontmanNextjs__Sentry

@@live
let setup = (): (
  FrontmanNextjs__OpenTelemetry__Bindings.Logs.logRecordProcessor,
  FrontmanNextjs__OpenTelemetry__Bindings.Trace.spanProcessor,
) => {
  LogCapture.initialize()
  FrontmanBindings.Process.envString("SENTRY_DSN")->Option.forEach(dsn => Sentry.initialize(~dsn))

  (FrontmanNextjs__LogRecordProcessor.make(), FrontmanNextjs__SpanProcessor.make())
}
