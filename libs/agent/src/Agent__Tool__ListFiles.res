// List files tool
module Bindings = AskTheLlmBindings

let name = "listFiles"
let description = "List files in a relative directory to the project root"

@schema
type input = {relative_dir: string}

@schema
type fileEntry = {
  name: string,
  path: string,
  isFile: bool,
  isDirectory: bool,
}

@schema
type output = array<fileEntry>

let decodeInput: JSON.t => result<input, S.error> = json => {
  try {
    Ok(json->S.parseOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertOrThrow(outputSchema)->Obj.magic
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<output> => {
  let fullPath = Bindings.Path.join([ctx.projectRoot, input.relative_dir])

  try {
    let entries = await Bindings.Fs.Promises.readdir(fullPath)

    let entriesWithStats = await entries
    ->Array.map(async name => {
      let entryPath = Bindings.Path.join([fullPath, name])
      let stats = await Bindings.Fs.Promises.stat(entryPath)

      {
        name,
        path: Bindings.Path.join([input.relative_dir, name]),
        isFile: Bindings.Fs.isFile(stats),
        isDirectory: Bindings.Fs.isDirectory(stats),
      }
    })
    ->Promise.all

    Ok(entriesWithStats)
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")

      // Provide helpful error message with suggestions
      let errorMsg = if message->String.includes("ENOENT") {
        `Directory not found: "${input.relative_dir}".
        The directory does not exist in the project.
        Try using ${name} tool with directory="." to see the root structure,
        or list the parent directory to understand what's available.`
      } else {
        `Failed to list files in ${input.relative_dir}: ${message}`
      }

      Error(errorMsg)
    }
  }
}
