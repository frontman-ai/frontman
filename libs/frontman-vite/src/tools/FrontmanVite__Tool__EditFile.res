module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module CoreEditFile = Core.FrontmanCore__Tool__EditFile
module EditFileWithLogCheck = Core.FrontmanCore__Tool__EditFileWithLogCheck

let name = "edit_file"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let visibleToAgent = true
let description = CoreEditFile.description

type input = CoreEditFile.input
type output = CoreEditFile.output

let inputSchema = CoreEditFile.inputSchema
let outputSchema = CoreEditFile.outputSchema

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  await EditFileWithLogCheck.execute(
    ctx,
    input,
    ~getErrorLogsSince=EditFileWithLogCheck.getCoreErrorLogsSince,
  )
}
