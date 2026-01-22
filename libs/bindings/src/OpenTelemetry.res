// OpenTelemetry SDK bindings for ReScript
// Minimal FFI bindings for OTEL types needed by processors

// High-resolution time: [seconds, nanoseconds]
type hrTime = (float, float)

// Span/log context
type context

// Attributes dictionary
type attributes = Dict.t<JSON.t>

// === SDK Logs Bindings ===

module Logs = {
  // Resource type
  type resource
  @get @return(nullable) external resourceAttributes: resource => option<attributes> = "attributes"

  // SDK log record
  type sdkLogRecord
  @get external hrTime: sdkLogRecord => hrTime = "hrTime"
  @get @return(nullable) external body: sdkLogRecord => option<string> = "body"
  @get @return(nullable) external severityText: sdkLogRecord => option<string> = "severityText"
  @get @return(nullable) external attributes: sdkLogRecord => option<attributes> = "attributes"
  @get @return(nullable) external resource: sdkLogRecord => option<resource> = "resource"

  // LogRecordProcessor interface (what user passes to OTEL SDK)
  type logRecordProcessor = {
    "onEmit": (sdkLogRecord, option<context>) => unit,
    "forceFlush": unit => promise<unit>,
    "shutdown": unit => promise<unit>,
  }

  @new external makeProcessor: {..} => logRecordProcessor = "Object"
}

// === SDK Trace Bindings ===

module Trace = {
  // Readable span (completed)
  type readableSpan
  @get external name: readableSpan => string = "name"
  @get external kind: readableSpan => int = "kind"
  @get external startTime: readableSpan => hrTime = "startTime"
  @get external endTime: readableSpan => hrTime = "endTime"
  @get external attributes: readableSpan => attributes = "attributes"

  // Regular span (in-flight)
  type span

  // Tracer for creating spans
  type tracer

  // TracerProvider for managing tracers
  type tracerProvider

  // SpanProcessor interface
  type spanProcessor = {
    "onStart": (span, context) => unit,
    "onEnd": readableSpan => unit,
    "forceFlush": unit => promise<unit>,
    "shutdown": unit => promise<unit>,
  }

  @new external makeProcessor: {..} => spanProcessor = "Object"
}
