// List files tool - lists directory contents

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "list_files"
let visibleToAgent = true
let description = `Lists files and directories in a given path.

Parameters:
- path (optional): Relative path to directory from source root. Defaults to "." (root directory). Use "." to list the source root.

Returns array of entries with name, path, and type information.`

@schema
type input = {path?: string}

@schema
type fileEntry = {
  name: string,
  path: string,
  isFile: bool,
  isDirectory: bool,
}

@schema
type output = array<fileEntry>

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let path = input.path->Option.getOr(".")
  let fullPath = Path.join([ctx.sourceRoot, path])

  try {
    let entries = await Fs.Promises.readdir(fullPath)

    let entriesWithStats = await entries
    ->Array.map(async name => {
      let entryPath = Path.join([fullPath, name])
      let stats = await Fs.Promises.stat(entryPath)

      {
        name,
        path: Path.join([path, name]),
        isFile: Fs.isFile(stats),
        isDirectory: Fs.isDirectory(stats),
      }
    })
    ->Promise.all

    Ok(entriesWithStats)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to list files in ${path}: ${msg}`)
  }
}
