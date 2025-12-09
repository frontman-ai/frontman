// File exists tool - checks if a file or directory exists

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "file_exists"

let description = `Checks if a file or directory exists.

Parameters:
- path (required): Relative path from project root

Returns true if the path exists, false otherwise.`

@schema
type input = {
  path: string,
}

@schema
type output = bool

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let fullPath = Path.join([ctx.projectRoot, input.path])

  try {
    await Fs.Promises.access(fullPath)
    Ok(true)
  } catch {
  | _ => Ok(false)
  }
}
