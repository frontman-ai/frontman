// File exists tool - checks if a file or directory exists

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ProjectPath = FrontmanCore__ProjectPath
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
  switch ProjectPath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(msg) => Error(msg)
  | Ok(projectPath) =>
    let exists = await FsUtils.pathExists(ProjectPath.toString(projectPath))
    Ok(exists)
  }
}
