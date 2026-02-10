open FrontmanNextjs__OpenTelemetry__Bindings

module LogCapture = FrontmanNextjs__LogCapture

let hrTimeToISO = ((seconds, nanos): hrTime): string => {
  let ms = seconds *. 1000.0 +. nanos /. 1_000_000.0
  ms->Date.fromTime->Date.toISOString
}

let calculateDuration = (span: Trace.readableSpan): float => {
  let (startSec, startNano) = span->Trace.startTime
  let (endSec, endNano) = span->Trace.endTime
  let startMs = startSec *. 1000.0 +. startNano /. 1_000_000.0
  let endMs = endSec *. 1000.0 +. endNano /. 1_000_000.0
  endMs -. startMs
}

let getStr = (attrs: attributes, key: string): option<string> => {
  attrs->Dict.get(key)->Option.flatMap(JSON.Decode.string)
}

let getNum = (attrs: attributes, key: string): option<float> => {
  attrs->Dict.get(key)->Option.flatMap(JSON.Decode.float)
}

let make = (): Trace.spanProcessor => {
  let onStart = (_span: Trace.span, _ctx: context): unit => ()

  let onEnd = (span: Trace.readableSpan): unit => {
    try {
      let attrs = span->Trace.attributes
      let spanType = getStr(attrs, "next.span_type")

      let relevantTypes = [
        "BaseServer.handleRequest",
        "AppRender.getBodyResult",
        "AppRouteRouteHandlers.runHandler",
      ]

      let isRelevant = spanType->Option.mapOr(false, st => relevantTypes->Array.includes(st))

      if isRelevant {
        let httpMethod = getStr(attrs, "http.method")
        let route = switch getStr(attrs, "next.route") {
        | Some(r) => Some(r)
        | None => getStr(attrs, "http.route")
        }
        let statusCode = getNum(attrs, "http.status_code")
        let path = route->Option.getOr("unknown")

        if !(path == "/frontman" || path->String.startsWith("/frontman/")) {
          let durationMs = calculateDuration(span)

          let (message, level) = switch spanType {
          | Some("BaseServer.handleRequest") => {
              let method = httpMethod->Option.getOr("UNKNOWN")
              let status =
                statusCode->Option.map(code => Float.toString(code))->Option.getOr("unknown")
              let msg = `${method} ${path} ${status} ${durationMs->Float.toFixed(~digits=2)}ms`
              let lvl =
                statusCode->Option.mapOr(LogCapture.Console, code =>
                  code >= 500.0 ? LogCapture.Error : LogCapture.Console
                )
              (msg, lvl)
            }
          | Some("AppRender.getBodyResult") => {
              let msg = `Rendered route: ${path} (${durationMs->Float.toFixed(~digits=2)}ms)`
              (msg, LogCapture.Console)
            }
          | Some("AppRouteRouteHandlers.runHandler") => {
              let msg = `API route: ${path} (${durationMs->Float.toFixed(~digits=2)}ms)`
              (msg, LogCapture.Console)
            }
          | _ => ("", LogCapture.Console)
          }

          if message != "" {
            let logAttrs =
              Dict.fromArray([
                ("log.origin", "opentelemetry-span"->JSON.Encode.string),
                ("span.name", span->Trace.name->JSON.Encode.string),
                ("span.type", spanType->Option.getOr("")->JSON.Encode.string),
                ("http.method", httpMethod->Option.getOr("")->JSON.Encode.string),
                ("http.route", route->Option.getOr("")->JSON.Encode.string),
                (
                  "http.status_code",
                  statusCode->Option.map(JSON.Encode.float)->Option.getOr(JSON.Encode.null),
                ),
                ("duration.ms", durationMs->JSON.Encode.float),
              ])->JSON.Encode.object

            let (endSec, endNano) = span->Trace.endTime
            let _timestamp = (endSec, endNano)->hrTimeToISO

            let state = LogCapture.getInstance()
            LogCapture.addLog(state, level, message, ~attributes=logAttrs)
          }
        }
      }
    } catch {
    | _ => ()
    }
  }

  let forceFlush = (): promise<unit> => Promise.resolve()
  let shutdown = (): promise<unit> => Promise.resolve()

  Trace.makeProcessor({
    "onStart": onStart,
    "onEnd": onEnd,
    "forceFlush": forceFlush,
    "shutdown": shutdown,
  })
}
