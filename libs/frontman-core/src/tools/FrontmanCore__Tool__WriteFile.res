// Write file tool - writes content to a file

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "write_file"

let description = `Writes content to a file.

Parameters:
- path (required): Relative path to file from source root
- content (required): Content to write

Creates parent directories if they don't exist. Overwrites existing files.`

@schema
type input = {
  path: string,
  content: string,
}

// Null output for tools that don't return data
type output
external nullValue: output = "null"
let outputSchema = S.literal(nullValue)

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let fullPath = Path.join([ctx.sourceRoot, input.path])
  let dirPath = Path.dirname(fullPath)

  try {
    let _ = await Fs.Promises.mkdir(dirPath, {recursive: true})
    await Fs.Promises.writeFile(fullPath, input.content)
    Ok(nullValue)
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to write file ${input.path}: ${msg}`)
  }
}
