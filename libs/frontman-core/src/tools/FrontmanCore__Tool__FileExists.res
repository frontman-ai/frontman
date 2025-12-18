// File exists tool - checks if a file or directory exists

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "file_exists"
let visibleToAgent = true
let description = `Checks if a file or directory exists.

Parameters:
- path (required): Relative path from source root

Returns true if the path exists, false otherwise.`

@schema
type input = {path: string}

@schema
type output = bool

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let fullPath = Path.join([ctx.sourceRoot, input.path])

  try {
    await Fs.Promises.access(fullPath)
    Ok(true)
  } catch {
  | _ => Ok(false)
  }
}
