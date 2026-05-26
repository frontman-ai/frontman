module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module CoreEditFile = FrontmanCore__Tool__EditFile

type logEntry = {
  timestamp: string,
  message: string,
}

let sleep = (ms: int): promise<unit> => {
  Promise.make((resolve, _) => {
    let _ = setTimeout(() => resolve(), ms)
  })
}

let execute = async (
  ctx: Tool.serverExecutionContext,
  input: CoreEditFile.input,
  ~getErrorLogsSince: float => array<logEntry>,
): Tool.toolResult<CoreEditFile.output> => {
  let beforeTimestamp = Date.now()
  let result = await CoreEditFile.execute(ctx, input)

  switch result {
  | Error(_) => result
  | Ok(output) =>
    await sleep(800)

    let allErrors = getErrorLogsSince(beforeTimestamp)
    switch allErrors->Array.length > 0 {
    | false => Ok(output)
    | true =>
      let errorMessages =
        allErrors
        ->Array.slice(~start=0, ~end=5)
        ->Array.map(entry => entry.message)
        ->Array.join("\n")
      Ok({
        ...output,
        message: output.message ++
        `\n\nWarning: Dev server errors detected after edit:\n${errorMessages}`,
      })
    }
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
