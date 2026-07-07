// File exists tool - checks if a file or directory exists

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath
module FsUtils = FrontmanCore__FsUtils

let name = Tool.ToolNames.fileExists
let access = Tool.Read
let visibleToAgent = true
let description = `Checks if a file or directory exists.

Parameters:
- path (required): Path to check - either relative to source root or absolute (must be under source root)

Returns true if the path exists, false otherwise.`

@schema
type input = {path: string}

@schema
type output = bool

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  | Ok(safePath) =>
    let exists = await FsUtils.pathExists(SafePath.toString(safePath))
    Tool.jsonResult(exists, outputSchema)
  }
}
