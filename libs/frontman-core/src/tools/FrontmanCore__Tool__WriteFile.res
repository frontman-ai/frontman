// Write file tool - writes content to a file

module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath

let name = "write_file"
let visibleToAgent = true
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
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
  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(msg) => Error(msg)
  | Ok(safePath) =>
    let dirPath = SafePath.dirname(safePath)
    try {
      let _ = await Fs.Promises.mkdir(dirPath, {recursive: true})
      await Fs.Promises.writeFile(SafePath.toString(safePath), input.content)
      Ok(nullValue)
    } catch {
    | exn =>
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to write file ${input.path}: ${msg}`)
    }
  }
}
