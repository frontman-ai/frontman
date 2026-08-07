type hrTime = (float, float)

type context

type attributes = Dict.t<JSON.t>

module Logs = {
  type resource
  @get @return(nullable) external resourceAttributes: resource => option<attributes> = "attributes"

  type sdkLogRecord
  @get external hrTime: sdkLogRecord => hrTime = "hrTime"
  @get @return(nullable) external body: sdkLogRecord => option<string> = "body"
  @get @return(nullable) external severityText: sdkLogRecord => option<string> = "severityText"
  @get @return(nullable) external attributes: sdkLogRecord => option<attributes> = "attributes"
  @get @return(nullable) external resource: sdkLogRecord => option<resource> = "resource"

  type logRecordProcessor = {
    "onEmit": (sdkLogRecord, option<context>) => unit,
    "forceFlush": unit => promise<unit>,
    "shutdown": unit => promise<unit>,
  }

  @new external makeProcessor: {..} => logRecordProcessor = "Object"
}

module Trace = {
  type readableSpan
  @get external name: readableSpan => string = "name"
  @get external kind: readableSpan => int = "kind"
  @get external startTime: readableSpan => hrTime = "startTime"
  @get external endTime: readableSpan => hrTime = "endTime"
  @get external attributes: readableSpan => attributes = "attributes"

  type span

  type tracer

  type tracerProvider

  type spanProcessor = {
    "onStart": (span, context) => unit,
    "onEnd": readableSpan => unit,
    "forceFlush": unit => promise<unit>,
    "shutdown": unit => promise<unit>,
  }

  @new external makeProcessor: {..} => spanProcessor = "Object"
}
