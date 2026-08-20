module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module CoreEditFile = FrontmanCore__Tool__EditFile
module FileChange = FrontmanCore__FileChange

type logEntry = {
  @live
  timestamp: string,
  message: string,
}

let sleep = (ms: int): promise<unit> => {
  Promise.make((resolve, _) => {
    let _ = setTimeout(() => resolve(), ms)
  })
}

@@live
let execute = async (
  ctx: Tool.serverExecutionContext,
  input: CoreEditFile.input,
  ~getErrorLogsSince: float => array<logEntry>,
): Tool.MCP.CallToolResult.t => {
  let beforeTimestamp = Date.now()

  switch await CoreEditFile.executeOutput(ctx, input) {
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  | Ok({output, fileChange}) =>
    await sleep(800)

    let message = switch getErrorLogsSince(beforeTimestamp) {
    | [] => output.message
    | allErrors =>
      let errorMessages =
        allErrors
        ->Array.slice(~start=0, ~end=5)
        ->Array.map(entry => entry.message)
        ->Array.join("\n")
      output.message ++ `\n\nWarning: Dev server errors detected after edit:\n${errorMessages}`
    }

    FileChange.textResultWithFileChange(
      ~message,
      ~output={...output, message},
      ~outputSchema=CoreEditFile.outputSchema,
      fileChange,
    )
  }
}
let getCoreErrorLogsSince = (beforeTimestamp: float): array<logEntry> => {
  let recentLogs = FrontmanCore__LogCapture.getLogs(~since=beforeTimestamp, ~level=Error)
  let errorLogs = FrontmanCore__LogCapture.getLogs(
    ~since=beforeTimestamp,
    ~pattern="error|Error|failed|Failed",
  )

  let seen = Set.make()
  recentLogs->Array.forEach(entry => seen->Set.add(entry.timestamp ++ "|" ++ entry.message))
  Array.concat(
    recentLogs->Array.map(entry => {timestamp: entry.timestamp, message: entry.message}),
    errorLogs
    ->Array.filter(entry => !(seen->Set.has(entry.timestamp ++ "|" ++ entry.message)))
    ->Array.map(entry => {timestamp: entry.timestamp, message: entry.message}),
  )
}
