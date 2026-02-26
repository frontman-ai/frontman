// File exists tool - checks if a file or directory exists

module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath
module FsUtils = FrontmanCore__FsUtils

let name = Tool.ToolNames.fileExists
let visibleToAgent = true
let description = `Checks if a file or directory exists.

Parameters:
- path (required): Path to check - either relative to source root or absolute (must be under source root)

Returns true if the path exists, false otherwise.`

@schema
type input = {path: string}

@schema
type output = bool

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(msg) => Error(msg)
  | Ok(safePath) =>
    let exists = await FsUtils.pathExists(SafePath.toString(safePath))
    Ok(exists)
  }
}
