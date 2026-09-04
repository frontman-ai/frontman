module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FsUtils = FrontmanCore__FsUtils

let name = Tool.ToolNames.fileExists
let access = Tool.Read
let description = `Checks if a file or directory exists.

Parameters:
- path (required): Path to check - either relative to source root or absolute (must be under source root)

Returns true if the path exists, false otherwise.`

@schema
type input = {path: string}

@schema
type output = bool

let (visibleToAgent, outputJsonSchema) = (true, None)

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(err) => Tool.MCP.CallToolResult.makeError(PathContext.formatError(err))
  | Ok(resolved) =>
    let exists = await FsUtils.pathExists(resolved.resolvedPath)
    Tool.unstructuredResult(exists, outputSchema)
  }
}
