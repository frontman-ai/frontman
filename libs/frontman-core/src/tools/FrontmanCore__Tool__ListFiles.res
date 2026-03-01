// List files tool - lists directory contents

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.listFiles
let visibleToAgent = true
let description = `Lists files and directories in a single directory.

WHEN TO USE THIS TOOL:
- Browsing one directory's immediate contents in detail (names, types)
- Checking what files exist in a specific directory before reading or editing
- Verifying file organization after making changes
- Use list_tree instead when you need a multi-level project overview or monorepo layout
- Use search_files instead when you need to find files by name pattern across the project

PARAMETERS:
- path (optional): Path to directory - either relative to source root or absolute (must be under source root). Defaults to "." (root directory).

OUTPUT:
Returns array of entries with name, path, and type (file or directory) information.
Respects .gitignore — ignored files are excluded from results.`

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

// Get entries that are ignored by git (respects .gitignore)
let getIgnoredEntries = async (~cwd: string, entries: array<string>): result<
  array<string>,
  string,
> => {
  if Array.length(entries) == 0 {
    Ok([])
  } else {
    try {
      let entriesArg = entries->Array.join("\n")
      let command = `printf "%s" "${entriesArg}" | git check-ignore --stdin`
      let result = await ChildProcess.execWithOptions(command, {cwd: cwd})

      switch result {
      | Ok({stdout}) => Ok(stdout->String.trim->String.split("\n")->Array.filter(s => s !== ""))
      | Error({code: Some(1), _}) => Ok([]) // Exit code 1 = no files ignored
      | Error({code: Some(128), stderr}) => Error(`Not a git repository: ${stderr}`)
      | Error({stderr}) => Error(`git check-ignore failed: ${stderr}`)
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`git check-ignore error: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let path = input.path->Option.getOr(".")

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    try {
      let fullPath = result.resolvedPath
      let entries = await Fs.Promises.readdir(fullPath)

      let filteredEntriesResult =
        (await getIgnoredEntries(~cwd=fullPath, entries))->Result.map(ignored =>
          entries->Array.filter(name => !(ignored->Array.includes(name)))
        )

      switch filteredEntriesResult {
      | Error(msg) => Error(msg)
      | Ok(filteredEntries) =>
        let entriesWithStats = await filteredEntries
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
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to list files in ${path}: ${msg}`)
    }
  }
}
