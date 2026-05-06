module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module CoreEditFile = Core.FrontmanCore__Tool__EditFile
module EditFileWithLogCheck = Core.FrontmanCore__Tool__EditFileWithLogCheck
module LogCapture = FrontmanNextjs__LogCapture

let name = "edit_file"
let visibleToAgent = true
let description = CoreEditFile.description

type input = CoreEditFile.input
type output = CoreEditFile.output

let inputSchema = CoreEditFile.inputSchema
let outputSchema = CoreEditFile.outputSchema

let getErrorLogsSince = (beforeTimestamp: float): array<EditFileWithLogCheck.logEntry> => {
  let recentLogs = LogCapture.getLogs(~since=beforeTimestamp, ~level=Error)
  let errorLogs = LogCapture.getLogs(~since=beforeTimestamp, ~pattern="error|Error|failed|Failed")
  let toSharedLogEntry = (entry: LogCapture.logEntry): EditFileWithLogCheck.logEntry => {
    timestamp: entry.timestamp,
    message: entry.message,
  }

  let seen = Set.make()
  recentLogs->Array.forEach(entry => seen->Set.add(entry.timestamp ++ "|" ++ entry.message))
  Array.concat(
    recentLogs->Array.map(toSharedLogEntry),
    errorLogs
    ->Array.filter(entry => !(seen->Set.has(entry.timestamp ++ "|" ++ entry.message)))
    ->Array.map(toSharedLogEntry),
  )
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  await EditFileWithLogCheck.execute(ctx, input, ~getErrorLogsSince)
}
