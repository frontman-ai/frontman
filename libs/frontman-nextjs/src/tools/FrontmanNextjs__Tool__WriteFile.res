module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module CoreWriteFile = Core.FrontmanCore__Tool__WriteFile

let name = Tool.ToolNames.writeFile
let access = Tool.Write
let description = CoreWriteFile.description

type input = CoreWriteFile.input

let inputSchema = CoreWriteFile.inputSchema
let (visibleToAgent, outputJsonSchema) = (true, CoreWriteFile.outputJsonSchema)

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await CoreWriteFile.executeWithFileChange(ctx, input) {
  | Ok(execution) =>
    Core.FrontmanCore__FileChange.textResult(~message="File written successfully.", execution.fileChange)
  | Error(message) => Tool.MCP.CallToolResult.makeError(message)
  }
}
