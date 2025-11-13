// Check if file exists tool
module Bindings = AskTheLlmBindings

let name = "file_exists"
let description = "Check if a file or directory exists in the project"

@schema
type input = {relativePath: string}

@schema
type output = bool

let decodeInput = json => {
  try {
    Ok(json->S.parseOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.convertToJsonOrThrow(outputSchema)
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
  output,
> => {
  let fullPath = Bindings.Path.join([ctx.projectRoot, input.relativePath])

  module Consts = Bindings.Fs.Promises.Constants
  try {
    await Bindings.Fs.Promises.accessWithMode(fullPath, Int.bitwiseOr(Consts.r_OK, Consts.w_OK))
    Ok(true)
  } catch {
  | _ => Ok(false)
  }
}
