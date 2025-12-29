// OpenTelemetry integration for Frontman
// Opt-in: requires user to install @opentelemetry/* packages

module Bindings = FrontmanNextjs__OpenTelemetry__Bindings

// Processor factories (return OTEL processor objects)
let makeLogRecordProcessor = FrontmanNextjs__LogRecordProcessor.make
let makeSpanProcessor = FrontmanNextjs__SpanProcessor.make

// Convenience: create both at once
let makeProcessors = () => (makeLogRecordProcessor(), makeSpanProcessor())
