// OpenTelemetry instrumentation for Next.js
// Simple setup that returns pre-configured processors

module LogCapture = FrontmanNextjs__LogCapture

// Simple setup - call this in your instrumentation.ts register() function
// Returns [logRecordProcessor, spanProcessor] ready to use with NodeSDK
let setup = (): (
  FrontmanNextjs__OpenTelemetry__Bindings.Logs.logRecordProcessor,
  FrontmanNextjs__OpenTelemetry__Bindings.Trace.spanProcessor,
) => {
  // Initialize LogCapture (patches console, stdout, errors)
  LogCapture.initialize()

  // Return OTEL processors
  (FrontmanNextjs__LogRecordProcessor.make(), FrontmanNextjs__SpanProcessor.make())
}
