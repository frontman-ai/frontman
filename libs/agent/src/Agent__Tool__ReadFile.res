// Read file tool
module Bindings = AskTheLlmBindings

let name = "read_file"
let description = "Read contents of a file from the project"

type input = {relativePath: string}
type output = string

let inputSchemaS = S.object((s): input => {
  relativePath: s.field("relativePath", S.string),
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
  output->S.reverseConvertOrThrow(S.string)->Obj.magic
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<output> => {
  let fullPath = Bindings.Path.join([ctx.projectRoot, input.relativePath])

  try {
    let content = await Bindings.Fs.Promises.readFile(fullPath)
    Ok(content)
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")

      // Provide helpful error message with suggestions
      let errorMsg = if message->String.includes("ENOENT") {
        `File not found: "${input.relativePath}". ` ++
        `The file does not exist in the project. ` ++ `Use list_files to explore the directory structure and find the correct path.`
      } else if message->String.includes("EISDIR") {
        `Cannot read "${input.relativePath}" because it's a directory, not a file. ` ++ `Use list_files to see the contents of this directory.`
      } else {
        `Failed to read file ${input.relativePath}: ${message}`
      }

      Error(errorMsg)
    }
  }
}
