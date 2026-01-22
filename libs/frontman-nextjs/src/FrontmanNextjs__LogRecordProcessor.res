open FrontmanNextjs__OpenTelemetry__Bindings

module LogCapture = FrontmanNextjs__LogCapture

let mapSeverity = (severityText: option<string>): LogCapture.logLevel => {
  switch severityText {
  | Some("ERROR") | Some("FATAL") | Some("CRITICAL") => LogCapture.Error
  | Some("WARN") | Some("WARNING") => LogCapture.Console
  | _ => LogCapture.Console
  }
}

let hrTimeToISO = ((seconds, nanos): hrTime): string => {
  let ms = seconds *. 1000.0 +. nanos /. 1_000_000.0
  ms->Date.fromTime->Date.toISOString
}

let make = (): Logs.logRecordProcessor => {
  let onEmit = (logRecord: Logs.sdkLogRecord, _context: option<context>): unit => {
    try {
      let body = logRecord->Logs.body->Option.getOr("")
      let level = logRecord->Logs.severityText->mapSeverity

      let attributes = logRecord->Logs.attributes->Option.map(attrs => attrs->JSON.Encode.object)

      let state = LogCapture.getInstance()
      LogCapture.addLog(state, level, body, ~attributes?)
    } catch {
    | _ => ()
    }
  }

  let forceFlush = (): promise<unit> => Promise.resolve()
  let shutdown = (): promise<unit> => Promise.resolve()

  Logs.makeProcessor({
    "onEmit": onEmit,
    "forceFlush": forceFlush,
    "shutdown": shutdown,
  })
}
