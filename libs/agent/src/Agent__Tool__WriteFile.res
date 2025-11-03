module Bindings = AskTheLlmBindings

let name = "write_file"
let description = "Write contents to a file in the project"

@schema
type input = {
  relativePath: string,
  content: string,
}
@schema
type output = unit

let decodeInput: JSON.t => result<input, S.error> = json => {
  try {
    Ok(json->S.parseJsonOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertToJsonOrThrow(outputSchema)
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
  output,
> => {
  let fullPath = Bindings.Path.join([ctx.projectRoot, input.relativePath])

  try {
    await Bindings.Fs.Promises.writeFile(fullPath, input.content)
    Ok()
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to write file ${input.relativePath}: ${message}`)
    }
  }
}
