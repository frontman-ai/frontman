// Write file tool
module Bindings = AskTheLlmBindings

let name = "write_file"
let description = "Write contents to a file in the project"

type input = {
  relativePath: string,
  content: string,
}
type output = unit

let inputSchemaS = S.object((s): input => {
  relativePath: s.field("relativePath", S.string),
  content: s.field("content", S.string),
})

let inputSchema = inputSchemaS->S.toJSONSchema

let decodeInput = json => {
  try {
    Ok(json->S.parseOrThrow(inputSchemaS))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertOrThrow(S.unit)->Obj.magic
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<output> => {
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
