module LogCapture = FrontmanNextjs__LogCapture

let setup = (): (
  FrontmanNextjs__OpenTelemetry__Bindings.Logs.logRecordProcessor,
  FrontmanNextjs__OpenTelemetry__Bindings.Trace.spanProcessor,
) => {
  LogCapture.initialize()

  (FrontmanNextjs__LogRecordProcessor.make(), FrontmanNextjs__SpanProcessor.make())
}
