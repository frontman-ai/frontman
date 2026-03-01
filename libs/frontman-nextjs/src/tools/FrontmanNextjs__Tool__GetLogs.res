module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module LogCapture = FrontmanNextjs__LogCapture

let name = "get_logs"
let visibleToAgent = true
let description = `Retrieves server logs from rotating 1024-entry buffer.

Captures:
- Console output (console.log, warn, error, info, debug)
- Next.js build logs (webpack/turbopack compilation)
- Uncaught exceptions with stack traces

Parameters:
- pattern (optional): JavaScript regex pattern to filter messages (case-insensitive)
  Examples: "error", "webpack.*compiled", "TypeError"
- level (optional): Filter by log type: "console", "build", or "error"
- since (optional): ISO 8601 timestamp - only return logs after this time
  Example: "2025-12-28T10:30:00.000Z"
- tail (optional): Limit to most recent N entries
  Example: 100 (returns last 100 matching logs)

Returns logs in chronological order (oldest first within buffer).`

@schema
type input = {
  pattern: option<string>,
  level: option<LogCapture.logLevel>,
  since: option<string>,
  tail: option<int>,
}

@schema
type output = {
  logs: array<LogCapture.logEntry>,
  totalMatched: int,
  bufferSize: int,
  hasMore: bool,
}

let execute = async (_ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  try {
    let sinceTimestamp =
      input.since->Option.map(isoString => isoString->Date.fromString->Date.getTime)

    let allMatchedLogs = LogCapture.getLogs(
      ~pattern=?input.pattern,
      ~level=?input.level,
      ~since=?sinceTimestamp,
    )

    let totalMatched = allMatchedLogs->Array.length

    let logs = switch input.tail {
    | Some(n) => allMatchedLogs->Array.slice(~start=max(0, totalMatched - n), ~end=totalMatched)
    | None => allMatchedLogs
    }

    let hasMore = switch input.tail {
    | Some(n) => totalMatched > n
    | None => false
    }

    let bufferSize = LogCapture.getInstance().buffer.contents->FrontmanNextjs__CircularBuffer.length

    Ok({
      logs,
      totalMatched,
      bufferSize,
      hasMore,
    })
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to retrieve logs: ${msg}`)
  }
}
