module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module CoreEditFile = Core.FrontmanCore__Tool__EditFile
module EditFileWithLogCheck = Core.FrontmanCore__Tool__EditFileWithLogCheck
module LogCapture = FrontmanNextjs__LogCapture

let name = "edit_file"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let description = CoreEditFile.description

type input = CoreEditFile.input

let inputSchema = CoreEditFile.inputSchema
let (visibleToAgent, outputJsonSchema) = (true, CoreEditFile.outputJsonSchema)

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

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await EditFileWithLogCheck.executeWithFileChange(ctx, input, ~getErrorLogsSince) {
  | Ok(execution) =>
    Core.FrontmanCore__FileChange.textResult(~message=execution.output.message, execution.fileChange)
  | Error(message) => Tool.MCP.CallToolResult.makeError(message)
  }
}
